package video

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type TMDBFeatureProvider struct {
	apiKeys []string
	client  *http.Client
	cache   sync.Map
}

func NewTMDBFeatureProvider(apiKeys []string) *TMDBFeatureProvider {
	if len(apiKeys) == 0 {
		apiKeys = []string{
			"844dba0bfd8f3a4f3799f6130ef9e335",
			"e9e9d8da18ae29fc430845952232787c",
			"4113f36a3dce79e4deda2209210e3060",
		}
	}
	return &TMDBFeatureProvider{
		apiKeys: apiKeys,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

type tmdbSearchResponse struct {
	Results []struct {
		ID          int    `json:"id"`
		Title       string `json:"title"`
		Name        string `json:"name"`
		ReleaseDate string `json:"release_date"`
		Overview    string `json:"overview"`
	} `json:"results"`
}

type tmdbExternalIDsResponse struct {
	IMDBID string `json:"imdb_id"`
}

type tmdbVideosResponse struct {
	Results []struct {
		Key  string `json:"key"`
		Site string `json:"site"`
		Type string `json:"type"`
	} `json:"results"`
}

func cleanTitleForSearchVariants(raw string) []string {
	reYear := regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)
	withoutYear := strings.TrimSpace(reYear.ReplaceAllString(raw, ""))

	var candidates []string
	if withoutYear != "" && withoutYear != raw {
		candidates = append(candidates, withoutYear)
	}
	candidates = append(candidates, raw)

	seen := make(map[string]bool)
	var list []string
	for _, cand := range candidates {
		// 1. Replace '&' with 'and'
		s1 := strings.ReplaceAll(cand, "&", "and")
		s1 = cleanSymbols(s1)

		// 2. Replace '&' with space
		s2 := strings.ReplaceAll(cand, "&", " ")
		s2 = cleanSymbols(s2)

		// 3. Raw cleaned
		s3 := cleanSymbols(cand)

		for _, s := range []string{s1, s2, s3} {
			trimmed := strings.TrimSpace(s)
			if trimmed != "" && !seen[trimmed] {
				seen[trimmed] = true
				list = append(list, trimmed)
			}
		}
	}
	return list
}

func extractFlixHQSlug(link string) string {
	re := regexp.MustCompile(`/(?:movie|series)/(.+?)(?:-\d+)?/?$`)
	m := re.FindStringSubmatch(link)
	if len(m) > 1 {
		slug := m[1]
		reID := regexp.MustCompile(`-\d+$`)
		return strings.ToLower(reID.ReplaceAllString(slug, ""))
	}
	return ""
}

func cleanSymbols(s string) string {
	symbols := []string{":", "-", "'", "\"", ".", "!", "?", ",", "(", ")", "[", "]"}
	for _, sym := range symbols {
		s = strings.ReplaceAll(s, sym, " ")
	}
	words := strings.Fields(s)
	return strings.Join(words, " ")
}

// ScrapeFlixHQ searches flixhq.ws and extracts multi-server streams (Vidmoly, VidSrc, etc.) and subtitles
func (p *TMDBFeatureProvider) ScrapeFlixHQ(ctx context.Context, cleanTitle string) *model.StreamResult {
	cacheKey := strings.ToLower(strings.TrimSpace(cleanTitle))
	if cached, ok := p.cache.Load(cacheKey); ok {
		if res, valid := cached.(*model.StreamResult); valid && res != nil {
			return res
		}
	}
	variants := cleanTitleForSearchVariants(cleanTitle)
	if len(variants) == 0 {
		variants = []string{cleanTitle}
	}

	reYear := regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)
	rawQueryWords := strings.Fields(strings.ToLower(cleanSymbols(cleanTitle)))
	var queryWords []string
	for _, w := range rawQueryWords {
		if len(w) == 4 && (strings.HasPrefix(w, "19") || strings.HasPrefix(w, "20")) {
			continue
		}
		queryWords = append(queryWords, w)
	}
	if len(queryWords) == 0 {
		queryWords = rawQueryWords
	}

	var candidateLinks []string
	seenLinks := make(map[string]bool)

	for _, v := range variants {
		encodedQ := strings.ReplaceAll(v, " ", "%20")
		searchURLs := []string{
			fmt.Sprintf("https://flixhq.ws/search/%s", encodedQ),
			fmt.Sprintf("https://flixhq.ws/search/%s/", encodedQ),
		}

		for _, searchURL := range searchURLs {
			req, err := http.NewRequestWithContext(ctx, "GET", searchURL, nil)
			if err != nil {
				continue
			}
			req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

			resp, err := p.client.Do(req)
			if err != nil || resp.StatusCode != http.StatusOK {
				if resp != nil {
					resp.Body.Close()
				}
				continue
			}

			body, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				continue
			}
			html := string(body)

			reLink := regexp.MustCompile(`href=["'](https://flixhq\.ws/(?:movie|series)/[^"']+)["']`)
			matches := reLink.FindAllStringSubmatch(html, -1)
			for _, m := range matches {
				link := m[1]
				if !strings.HasSuffix(link, "/") {
					link += "/"
				}
				if !seenLinks[link] {
					seenLinks[link] = true
					candidateLinks = append(candidateLinks, link)
				}
			}
			if len(candidateLinks) > 0 {
				break
			}
		}
		if len(candidateLinks) > 0 {
			break
		}
	}

	if len(candidateLinks) == 0 {
		return nil
	}

	regNorm := regexp.MustCompile(`[^a-zA-Z0-9]+`)
	qNorm := strings.Trim(regNorm.ReplaceAllString(strings.ToLower(cleanTitle), "-"), "-")
	cleanWithoutYear := strings.TrimSpace(reYear.ReplaceAllString(cleanTitle, ""))
	qNormWithoutYear := strings.Trim(regNorm.ReplaceAllString(strings.ToLower(cleanWithoutYear), "-"), "-")

	junkKeywords := []string{
		"making-of", "the-making-of", "behind-the-scenes", "featurette",
		"trailer", "teaser", "review", "reaction", "interview", "bonus", "promotional",
	}

	type scoredLink struct {
		url   string
		score int
	}
	var scored []scoredLink
	for _, link := range candidateLinks {
		slug := extractFlixHQSlug(link)
		if slug == "" {
			continue
		}

		// Reject junk / behind the scenes / trailers
		isJunk := false
		for _, j := range junkKeywords {
			if strings.Contains(slug, j) {
				isJunk = true
				break
			}
		}
		if isJunk {
			continue
		}

		slugWords := strings.Split(slug, "-")

		// Exact slug match is top winner
		if slug == qNorm || (qNormWithoutYear != "" && slug == qNormWithoutYear) {
			scored = append(scored, scoredLink{url: link, score: 3000})
			continue
		}

		// Reject if primary query words (len >= 3) are completely missing
		missingWord := false
		for _, qw := range queryWords {
			if len(qw) >= 3 {
				foundWord := false
				for _, sw := range slugWords {
					if sw == qw {
						foundWord = true
						break
					}
				}
				if !foundWord {
					missingWord = true
					break
				}
			}
		}
		if missingWord {
			continue
		}

		score := 100
		for _, qw := range queryWords {
			for _, sw := range slugWords {
				if sw == qw {
					score += 100
				}
			}
		}

		// Penalize if slug starts with an unrelated prefix word (e.g. "intimate-obsession" vs "obsession")
		if len(slugWords) > len(queryWords) && len(queryWords) > 0 && slugWords[0] != queryWords[0] {
			score -= 1000
		}

		// Penalize extra words not in query
		extraCount := 0
		for _, sw := range slugWords {
			isQW := false
			for _, qw := range queryWords {
				if sw == qw {
					isQW = true
					break
				}
			}
			if !isQW {
				extraCount++
			}
		}
		score -= extraCount * 150

		if score > 0 {
			scored = append(scored, scoredLink{url: link, score: score})
		}
	}

	// Sort highest score first
	for i := 0; i < len(scored); i++ {
		for j := i + 1; j < len(scored); j++ {
			if scored[j].score > scored[i].score {
				scored[i], scored[j] = scored[j], scored[i]
			}
		}
	}

	// Try each candidate link until one produces streams
	for _, sl := range scored {
		pageURL := sl.url

		reqPage, err := http.NewRequestWithContext(ctx, "GET", pageURL, nil)
		if err != nil {
			continue
		}
		reqPage.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
		reqPage.Header.Set("Referer", "https://flixhq.ws/")

		respPage, err := p.client.Do(reqPage)
		if err != nil || respPage.StatusCode != http.StatusOK {
			if respPage != nil {
				respPage.Body.Close()
			}
			continue
		}

		bodyPage, _ := io.ReadAll(respPage.Body)
		respPage.Body.Close()
		pageHTML := string(bodyPage)

		reAjax := regexp.MustCompile(`/ajax/ajax\.php\?(?:vds|vdkz)=([a-zA-Z0-9+/=]+)`)
		ajaxMatches := reAjax.FindStringSubmatch(pageHTML)
		if len(ajaxMatches) < 2 {
			continue
		}

		ajaxParam := ajaxMatches[0]
		ajaxURL := fmt.Sprintf("https://flixhq.ws%s", ajaxParam)

		reqAjax, err := http.NewRequestWithContext(ctx, "GET", ajaxURL, nil)
		if err != nil {
			continue
		}
		reqAjax.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
		reqAjax.Header.Set("X-Requested-With", "XMLHttpRequest")
		reqAjax.Header.Set("Referer", pageURL)

		respAjax, err := p.client.Do(reqAjax)
		if err != nil || respAjax.StatusCode != http.StatusOK {
			if respAjax != nil {
				respAjax.Body.Close()
			}
			continue
		}

		bodyAjax, _ := io.ReadAll(respAjax.Body)
		respAjax.Body.Close()
		ajaxHTML := string(bodyAjax)

		reSrv := regexp.MustCompile(`data-srv=["']([^"']+)["']\s*data-id=["']([^"']+)["']`)
		srvMatches := reSrv.FindAllStringSubmatch(ajaxHTML, -1)
		if len(srvMatches) == 0 {
			continue
		}

		var sources []model.Source
		var subtitles []model.Subtitle

		for _, srv := range srvMatches {
			srvName := srv[1]
			srvLink := srv[2]

			if strings.Contains(srvLink, "subdrc.xyz") {
				reqSub, err := http.NewRequestWithContext(ctx, "GET", srvLink, nil)
				if err == nil {
					reqSub.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
					reqSub.Header.Set("Referer", "https://flixhq.ws/")
					respSub, err := p.client.Do(reqSub)
					if err == nil {
						bodySub, _ := io.ReadAll(respSub.Body)
						respSub.Body.Close()
						subHTML := string(bodySub)

						reM3U8 := regexp.MustCompile(`https?://[^\s"'<>]+\.m3u8[^\s"'<>]*`)
						m3u8Matches := reM3U8.FindAllString(subHTML, -1)
						if len(m3u8Matches) > 0 {
							sources = append(sources, model.Source{
								URL:     m3u8Matches[0],
								Quality: fmt.Sprintf("1080p HD (Server 1 - %s)", srvName),
								IsM3U8:  true,
							})
						}

						reVTT := regexp.MustCompile(`https?://[^\s"'<>]+\.vtt[^\s"'<>]*`)
						vttMatches := reVTT.FindAllString(subHTML, -1)
						for _, vtt := range vttMatches {
							lang := "English [CC]"
							vttLower := strings.ToLower(vtt)
							if strings.Contains(vttLower, "romanian") {
								lang = "Romanian"
							} else if strings.Contains(vttLower, "spanish") {
								lang = "Spanish"
							} else if strings.Contains(vttLower, "french") {
								lang = "French"
							} else if strings.Contains(vttLower, "german") {
								lang = "German"
							}
							subtitles = append(subtitles, model.Subtitle{
								URL:  vtt,
								Lang: lang,
							})
						}
					}
				}
			}
		}

		if len(sources) > 0 {
			if len(subtitles) == 0 {
				subtitles = append(subtitles, model.Subtitle{URL: "", Lang: "English (Auto)"})
			}
			res := &model.StreamResult{
				Sources:   sources,
				Subtitles: subtitles,
				Headers: map[string]string{
					"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
					"Referer":    "https://flixhq.ws/",
				},
			}
			p.cache.Store(cacheKey, res)
			return res
		}
	}

	return nil
}

// ResolveTMDBExternalStream finds TMDB ID & IMDB ID to provide multi-source movie/TV fallback streams
func (p *TMDBFeatureProvider) ResolveTMDBExternalStream(ctx context.Context, mediaID string, title string) *model.StreamResult {
	// Raw HTML webpage embeds (vidsrc, multiembed, 2embed) must NEVER be returned as video streams
	// because media players (mpv / media_kit) attempt to decode them as video containers, causing
	// Android Native SurfaceTexture to crash/freeze into a transparent-white unclickable overlay.
	return nil
}

// CheckUnreleasedOrTrailer checks if a title is unreleased or has an official trailer preview
func (p *TMDBFeatureProvider) CheckUnreleasedOrTrailer(ctx context.Context, cleanTitle string) *model.StreamResult {
	apiKey := p.apiKeys[0]
	searchURL := fmt.Sprintf("https://api.themoviedb.org/3/search/movie?query=%s&api_key=%s", url.QueryEscape(cleanTitle), apiKey)

	req, err := http.NewRequestWithContext(ctx, "GET", searchURL, nil)
	if err != nil {
		return nil
	}

	resp, err := p.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil
	}
	defer resp.Body.Close()

	var searchRes tmdbSearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&searchRes); err != nil || len(searchRes.Results) == 0 {
		return nil
	}

	movie := searchRes.Results[0]
	isFuture := false
	if movie.ReleaseDate != "" {
		if t, err := time.Parse("2006-01-02", movie.ReleaseDate); err == nil {
			if t.After(time.Now()) {
				isFuture = true
			}
		}
	}

	videosURL := fmt.Sprintf("https://api.themoviedb.org/3/movie/%d/videos?api_key=%s", movie.ID, apiKey)
	reqV, err := http.NewRequestWithContext(ctx, "GET", videosURL, nil)
	if err != nil {
		return nil
	}
	respV, err := p.client.Do(reqV)
	if err != nil || respV.StatusCode != http.StatusOK {
		return nil
	}
	defer respV.Body.Close()

	var vidsRes tmdbVideosResponse
	if err := json.NewDecoder(respV.Body).Decode(&vidsRes); err == nil && len(vidsRes.Results) > 0 {
		for _, v := range vidsRes.Results {
			if v.Site == "YouTube" && v.Key != "" {
				label := "Official Teaser Preview (1080p)"
				if !isFuture {
					label = "Official Feature Trailer (1080p)"
				}
				return &model.StreamResult{
					Sources: []model.Source{
						{
							URL:     fmt.Sprintf("https://www.youtube.com/watch?v=%s", v.Key),
							Quality: label,
							IsM3U8:  false,
						},
					},
					Subtitles: []model.Subtitle{
						{URL: "", Lang: "English"},
					},
				}
			}
		}
	}

	return nil
}

func (p *TMDBFeatureProvider) ResolveFeatureStream(ctx context.Context, mediaID string, title string) (*model.StreamResult, error) {
	displayTitle := title
	if displayTitle == "" {
		displayTitle = "Feature"
	}

	// 1. Try FlixHQ Real Multi-Source Scraper (Vidmoly Master HLS)
	flixRes := p.ScrapeFlixHQ(ctx, displayTitle)
	if flixRes != nil && len(flixRes.Sources) > 0 {
		return flixRes, nil
	}

	// 1b. If title includes a year (e.g. "The Paramedic 2020"), retry scraping without the year
	reYear := regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)
	titleWithoutYear := strings.TrimSpace(reYear.ReplaceAllString(displayTitle, ""))
	if titleWithoutYear != "" && titleWithoutYear != displayTitle {
		if res := p.ScrapeFlixHQ(ctx, titleWithoutYear); res != nil && len(res.Sources) > 0 {
			return res, nil
		}
	}

	// 1c. If mediaID has tmdb-movie-XXX or tmdb-tv-XXX, look up TMDB for alternative/original titles
	if strings.Contains(mediaID, "tmdb-") && len(p.apiKeys) > 0 {
		parts := strings.Split(mediaID, "-")
		if len(parts) >= 3 {
			mType := parts[1]
			tmdbID := parts[2]
			apiKey := p.apiKeys[0]
			endpoint := fmt.Sprintf("https://api.themoviedb.org/3/%s/%s?api_key=%s", mType, tmdbID, apiKey)
			req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
			if err == nil {
				resp, err := p.client.Do(req)
				if err == nil && resp.StatusCode == http.StatusOK {
					defer resp.Body.Close()
					var raw struct {
						Title         string `json:"title"`
						Name          string `json:"name"`
						OriginalTitle string `json:"original_title"`
						OriginalName  string `json:"original_name"`
					}
					if json.NewDecoder(resp.Body).Decode(&raw) == nil {
						log.Printf("[TMDB-RESOLVE] Raw Title=%q, Name=%q, OrigTitle=%q, OrigName=%q", raw.Title, raw.Name, raw.OriginalTitle, raw.OriginalName)
						altTitles := []string{raw.Title, raw.Name, raw.OriginalTitle, raw.OriginalName}
						for _, alt := range altTitles {
							alt = strings.TrimSpace(alt)
							if alt != "" && !strings.EqualFold(alt, displayTitle) {
								if res := p.ScrapeFlixHQ(ctx, alt); res != nil && len(res.Sources) > 0 {
									return res, nil
								}
								altClean := strings.TrimSpace(reYear.ReplaceAllString(alt, ""))
								if altClean != "" && altClean != alt {
									if res := p.ScrapeFlixHQ(ctx, altClean); res != nil && len(res.Sources) > 0 {
										return res, nil
									}
								}
							}
						}
					}
				}
			}
		}
	}

	// 2. Fallback to direct external verified video stream
	extRes := p.ResolveTMDBExternalStream(ctx, mediaID, displayTitle)
	if extRes != nil && len(extRes.Sources) > 0 {
		return extRes, nil
	}

	// Note: Never return raw YouTube webpage watch URLs as media streams.
	// Media players cannot play HTML watch pages, which causes players to buffer eternally.
	return nil, fmt.Errorf("no feature stream found for %s", displayTitle)
}
