package subtitle

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type SubtitleEngine struct {
	client    *http.Client
	tmdbKeys  []string
	keyIndex  int
	keyMutex  sync.Mutex
	cache     sync.Map
}

func NewSubtitleEngine(tmdbKeys ...[]string) *SubtitleEngine {
	var keys []string
	if len(tmdbKeys) > 0 && len(tmdbKeys[0]) > 0 {
		keys = tmdbKeys[0]
	} else {
		keys = []string{
			"844dba0bfd8f3a4f3799f6130ef9e335",
			"e9e9d8da18ae29fc430845952232787c",
			"4113f36a3dce79e4deda2209210e3060",
		}
	}

	return &SubtitleEngine{
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		tmdbKeys: keys,
	}
}

func (e *SubtitleEngine) getKey() string {
	e.keyMutex.Lock()
	defer e.keyMutex.Unlock()
	if len(e.tmdbKeys) == 0 {
		return "844dba0bfd8f3a4f3799f6130ef9e335"
	}
	k := e.tmdbKeys[e.keyIndex%len(e.tmdbKeys)]
	e.keyIndex++
	return k
}

// GetSubtitles retrieves multi-language subtitles for a given media item
func (e *SubtitleEngine) GetSubtitles(ctx context.Context, mediaID string, title string) ([]model.Subtitle, error) {
	encTitle := url.QueryEscape(title)
	if encTitle == "" {
		encTitle = "Feature"
	}

	// 1. Check cache first
	cacheKey := fmt.Sprintf("%s_%s", mediaID, title)
	if val, ok := e.cache.Load(cacheKey); ok {
		if cachedSubs, ok := val.([]model.Subtitle); ok && len(cachedSubs) > 0 {
			return cachedSubs, nil
		}
	}

	// 2. Resolve IMDb ID
	imdbID := e.resolveImdbID(ctx, mediaID, title)

	var dynamicSubs []model.Subtitle
	if imdbID != "" {
		dynamicSubs = e.fetchStremioSubtitles(ctx, imdbID, title)
	}

	if len(dynamicSubs) > 0 {
		e.cache.Store(cacheKey, dynamicSubs)
		return dynamicSubs, nil
	}

	// 3. Fallback standard multi-language subtitles
	subs := []model.Subtitle{
		{URL: "", Lang: "Off"},
		{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=en&title=%s", encTitle), Lang: "English [CC]"},
		{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=es&title=%s", encTitle), Lang: "Spanish (Español)"},
		{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=fr&title=%s", encTitle), Lang: "French (Français)"},
		{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=de&title=%s", encTitle), Lang: "German (Deutsch)"},
	}

	cleanTitle := strings.ToLower(title)
	if strings.Contains(cleanTitle, "night of the living dead") {
		return []model.Subtitle{
			{URL: "", Lang: "Off"},
			{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=en&title=%s", encTitle), Lang: "English [CC]"},
			{URL: fmt.Sprintf("/api/v1/subtitles/vtt?lang=es&title=%s", encTitle), Lang: "Spanish (Español)"},
		}, nil
	}

	return subs, nil
}

func (e *SubtitleEngine) resolveImdbID(ctx context.Context, mediaID string, title string) string {
	// If already in tt format
	reIMDb := regexp.MustCompile(`tt\d{6,10}`)
	if m := reIMDb.FindString(mediaID); m != "" {
		return m
	}

	// Check if TMDB ID present
	cleanID := mediaID
	isTV := strings.Contains(cleanID, "-tv")
	tmdbID := ""

	reTMDB := regexp.MustCompile(`tmdb-(?:movie|tv)-(\d+)`)
	if match := reTMDB.FindStringSubmatch(cleanID); len(match) > 1 {
		tmdbID = match[1]
	}

	if tmdbID != "" {
		endpoint := fmt.Sprintf("https://api.themoviedb.org/3/movie/%s/external_ids?api_key=%s", tmdbID, e.getKey())
		if isTV {
			endpoint = fmt.Sprintf("https://api.themoviedb.org/3/tv/%s/external_ids?api_key=%s", tmdbID, e.getKey())
		}
		req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
		if err == nil {
			resp, err := e.client.Do(req)
			if err == nil && resp.StatusCode == http.StatusOK {
				defer resp.Body.Close()
				var ext struct {
					ImdbID string `json:"imdb_id"`
				}
				if json.NewDecoder(resp.Body).Decode(&ext) == nil && ext.ImdbID != "" {
					return ext.ImdbID
				}
			} else if resp != nil {
				resp.Body.Close()
			}
		}
	}

	// Try resolving via TMDB Search by Title
	if title != "" {
		q := url.QueryEscape(title)
		endpoint := fmt.Sprintf("https://api.themoviedb.org/3/search/movie?api_key=%s&query=%s", e.getKey(), q)
		req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
		if err == nil {
			resp, err := e.client.Do(req)
			if err == nil && resp.StatusCode == http.StatusOK {
				defer resp.Body.Close()
				var searchRes struct {
					Results []struct {
						ID int `json:"id"`
					} `json:"results"`
				}
				if json.NewDecoder(resp.Body).Decode(&searchRes) == nil && len(searchRes.Results) > 0 {
					firstID := searchRes.Results[0].ID
					extURL := fmt.Sprintf("https://api.themoviedb.org/3/movie/%d/external_ids?api_key=%s", firstID, e.getKey())
					reqExt, err := http.NewRequestWithContext(ctx, "GET", extURL, nil)
					if err == nil {
						respExt, err := e.client.Do(reqExt)
						if err == nil && respExt.StatusCode == http.StatusOK {
							defer respExt.Body.Close()
							var ext struct {
								ImdbID string `json:"imdb_id"`
							}
							if json.NewDecoder(respExt.Body).Decode(&ext) == nil && ext.ImdbID != "" {
								return ext.ImdbID
							}
						} else if respExt != nil {
							respExt.Body.Close()
						}
					}
				}
			} else if resp != nil {
				resp.Body.Close()
			}
		}
	}

	return ""
}

func (e *SubtitleEngine) fetchStremioSubtitles(ctx context.Context, imdbID string, title string) []model.Subtitle {
	urlEndpoint := fmt.Sprintf("https://opensubtitles-v3.strem.io/subtitles/movie/%s.json", imdbID)
	req, err := http.NewRequestWithContext(ctx, "GET", urlEndpoint, nil)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		if resp != nil {
			resp.Body.Close()
		}
		return nil
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}

	var res struct {
		Subtitles []struct {
			ID   string `json:"id"`
			URL  string `json:"url"`
			Lang string `json:"lang"`
		} `json:"subtitles"`
	}

	if err := json.Unmarshal(body, &res); err != nil || len(res.Subtitles) == 0 {
		return nil
	}

	langNames := map[string]string{
		"eng": "English",
		"en":  "English",
		"spa": "Spanish",
		"es":  "Spanish",
		"fre": "French",
		"fra": "French",
		"fr":  "French",
		"ger": "German",
		"deu": "German",
		"de":  "German",
		"ita": "Italian",
		"it":  "Italian",
		"por": "Portuguese",
		"pt":  "Portuguese",
		"zho": "Chinese",
		"chi": "Chinese",
		"zh":  "Chinese",
		"jpn": "Japanese",
		"ja":  "Japanese",
		"kor": "Korean",
		"ko":  "Korean",
		"rus": "Russian",
		"ru":  "Russian",
		"ara": "Arabic",
		"ar":  "Arabic",
		"hin": "Hindi",
		"hi":  "Hindi",
		"vie": "Vietnamese",
		"ind": "Indonesian",
		"id":  "Indonesian",
		"tha": "Thai",
		"pol": "Polish",
		"nld": "Dutch",
		"tur": "Turkish",
		"swe": "Swedish",
		"nor": "Norwegian",
		"dan": "Danish",
		"fin": "Finnish",
		"ell": "Greek",
		"heb": "Hebrew",
		"ces": "Czech",
		"cze": "Czech",
		"hun": "Hungarian",
		"ron": "Romanian",
		"rum": "Romanian",
	}

	var result []model.Subtitle
	result = append(result, model.Subtitle{URL: "", Lang: "Off"})

	seenLangs := make(map[string]bool)
	encTitle := url.QueryEscape(title)

	for _, s := range res.Subtitles {
		if s.URL == "" {
			continue
		}
		cleanCode := strings.ToLower(s.Lang)
		name, found := langNames[cleanCode]
		if !found {
			name = strings.ToUpper(cleanCode)
		}

		if !seenLangs[name] {
			seenLangs[name] = true
			displayLang := name
			if name == "English" {
				displayLang = "English [CC]"
			}
			proxyURL := fmt.Sprintf("/api/v1/subtitles/proxy?url=%s&title=%s&lang=%s",
				url.QueryEscape(s.URL),
				encTitle,
				url.QueryEscape(displayLang),
			)
			result = append(result, model.Subtitle{
				URL:  proxyURL,
				Lang: displayLang,
			})
		}
	}

	return result
}
