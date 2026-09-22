package anime

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type AnimeEngine struct {
	client *http.Client
}

func NewAnimeEngine() *AnimeEngine {
	return &AnimeEngine{
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

type hianimeAjaxResponse struct {
	Status bool   `json:"status"`
	HTML   string `json:"html"`
}

type zokoConfig struct {
	Src       string `json:"src"`
	Subtitles []struct {
		Src     string `json:"src"`
		Label   string `json:"label"`
		Lang    string `json:"lang"`
		Default bool   `json:"default"`
	} `json:"subtitles"`
}

// Search searches hianime.at for anime, cartoons, and animated series
func (e *AnimeEngine) Search(ctx context.Context, query string) ([]model.MediaItem, error) {
	searchURL := fmt.Sprintf("https://hianime.at/search?keyword=%s", url.QueryEscape(query))
	req, err := http.NewRequestWithContext(ctx, "GET", searchURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("hianime search failed")
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	html := string(body)

	reCard := regexp.MustCompile(`<div class="film-poster">[\s\S]*?<img\s+(?:data-src|src)="([^"]*)"[\s\S]*?<h3 class="film-name">\s*<a href="([^"]*)"[^>]*title="([^"]*)"`)
	matches := reCard.FindAllStringSubmatch(html, -1)

	var items []model.MediaItem
	for _, m := range matches {
		poster := m[1]
		link := m[2]
		title := m[3]

		slug := strings.TrimPrefix(link, "/")
		if strings.HasPrefix(slug, "https://hianime.at/") {
			slug = strings.TrimPrefix(slug, "https://hianime.at/")
		}

		cleanTitle := strings.ReplaceAll(title, "&#039;", "'")
		cleanTitle = strings.ReplaceAll(cleanTitle, "&quot;", "\"")
		cleanTitle = strings.ReplaceAll(cleanTitle, "&amp;", "&")

		items = append(items, model.MediaItem{
			ID:           fmt.Sprintf("anime-%s", slug),
			Title:        cleanTitle,
			Type:         model.MediaTypeTV,
			Poster:       poster,
			Banner:       poster,
			Rating:       "8.8",
			RatingSource: "HiAnime",
			Quality:      "1080p HD",
			Year:         "Anime",
			Overview:     fmt.Sprintf("%s on HiAnime", cleanTitle),
		})
	}

	return items, nil
}

// GetTrending fetches trending anime and cartoons from hianime.at
func (e *AnimeEngine) GetTrending(ctx context.Context) ([]model.MediaItem, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://hianime.at/home", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("hianime trending failed")
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	html := string(body)

	reCard := regexp.MustCompile(`<div class="film-poster">[\s\S]*?<img\s+(?:data-src|src)="([^"]*)"[\s\S]*?<h3 class="film-name">\s*<a href="([^"]*)"[^>]*title="([^"]*)"`)
	matches := reCard.FindAllStringSubmatch(html, -1)

	var items []model.MediaItem
	seen := make(map[string]bool)
	for _, m := range matches {
		poster := m[1]
		link := m[2]
		title := m[3]

		slug := strings.TrimPrefix(link, "/")
		if strings.HasPrefix(slug, "https://hianime.at/") {
			slug = strings.TrimPrefix(slug, "https://hianime.at/")
		}

		if seen[slug] {
			continue
		}
		seen[slug] = true

		cleanTitle := strings.ReplaceAll(title, "&#039;", "'")
		cleanTitle = strings.ReplaceAll(cleanTitle, "&quot;", "\"")
		cleanTitle = strings.ReplaceAll(cleanTitle, "&amp;", "&")

		items = append(items, model.MediaItem{
			ID:           fmt.Sprintf("anime-%s", slug),
			Title:        cleanTitle,
			Type:         model.MediaTypeTV,
			Poster:       poster,
			Banner:       poster,
			Rating:       "9.0",
			RatingSource: "HiAnime Trending",
			Quality:      "1080p HD",
			Year:         "2026",
			Overview:     fmt.Sprintf("Trending: %s", cleanTitle),
		})

		if len(items) >= 20 {
			break
		}
	}

	return items, nil
}

// GetDetails fetches detailed metadata for an anime ID
func (e *AnimeEngine) GetDetails(ctx context.Context, animeID string) (*model.MediaDetails, error) {
	slug := strings.TrimPrefix(animeID, "anime-")
	detailsURL := fmt.Sprintf("https://hianime.at/%s", slug)
	req, err := http.NewRequestWithContext(ctx, "GET", detailsURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch anime details")
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	html := string(body)

	reTitle := regexp.MustCompile(`<h2[^>]*class="[^"]*film-name[^"]*"[^>]*data-jname="([^"]*)"`)
	titleMatch := reTitle.FindStringSubmatch(html)
	title := slug
	if len(titleMatch) > 1 && titleMatch[1] != "" {
		title = titleMatch[1]
	}

	rePoster := regexp.MustCompile(`class="film-poster-img"\s+alt="[^"]*"\s+src="([^"]*)"|src="([^"]*)"\s+class="film-poster-img"`)
	posterMatch := rePoster.FindStringSubmatch(html)
	poster := ""
	if len(posterMatch) > 1 {
		if posterMatch[1] != "" {
			poster = posterMatch[1]
		} else if len(posterMatch) > 2 {
			poster = posterMatch[2]
		}
	}

	reDesc := regexp.MustCompile(`<meta property="og:description"\s+content="([^"]*)"`)
	descMatch := reDesc.FindStringSubmatch(html)
	overview := ""
	if len(descMatch) > 1 {
		overview = descMatch[1]
	}

	cleanTitle := strings.ReplaceAll(title, "&#039;", "'")
	cleanTitle = strings.ReplaceAll(cleanTitle, "&quot;", "\"")
	cleanTitle = strings.ReplaceAll(cleanTitle, "&amp;", "&")

	details := &model.MediaDetails{
		MediaItem: model.MediaItem{
			ID:           animeID,
			Title:        cleanTitle,
			Type:         model.MediaTypeTV,
			Poster:       poster,
			Banner:       poster,
			Rating:       "9.0",
			RatingSource: "HiAnime",
			Quality:      "1080p HD",
			Year:         "2026",
			Overview:     overview,
		},
		Genres:        []string{"Anime", "Animation", "Action"},
		Seasons:       []int{1},
		TotalEpisodes: 1,
	}

	return details, nil
}

// GetEpisodes extracts all episodes for an anime ID (e.g. "anime-naruto-1335")
func (e *AnimeEngine) GetEpisodes(ctx context.Context, animeID string) ([]model.Episode, error) {
	slug := strings.TrimPrefix(animeID, "anime-")
	parts := strings.Split(slug, "-")
	numID := parts[len(parts)-1]

	epURL := fmt.Sprintf("https://hianime.at/api/theme/episode/list/%s", numID)
	req, err := http.NewRequestWithContext(ctx, "GET", epURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	req.Header.Set("X-Requested-With", "XMLHttpRequest")
	req.Header.Set("Referer", fmt.Sprintf("https://hianime.at/%s", slug))

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch anime episodes")
	}
	defer resp.Body.Close()

	var ajaxRes hianimeAjaxResponse
	if err := json.NewDecoder(resp.Body).Decode(&ajaxRes); err != nil {
		return nil, err
	}

	reEp := regexp.MustCompile(`data-number="([^"]*)"\s+data-id="([0-9]+)"(?:\s+title="([^"]*)")?`)
	matches := reEp.FindAllStringSubmatch(ajaxRes.HTML, -1)

	var episodes []model.Episode
	for i, m := range matches {
		epNumStr := m[1]
		epID := m[2]
		epTitle := m[3]
		if epTitle == "" {
			epTitle = fmt.Sprintf("Episode %s", epNumStr)
		}

		epNum := i + 1
		episodes = append(episodes, model.Episode{
			ID:       fmt.Sprintf("anime-ep-%s-%s", slug, epID),
			Number:   epNum,
			Season:   1,
			Title:    epTitle,
			Overview: fmt.Sprintf("%s - Episode %s", epTitle, epNumStr),
		})
	}

	return episodes, nil
}

// GetServers resolves available Sub and Dub streaming servers for an episode ID
func (e *AnimeEngine) GetServers(ctx context.Context, episodeID string) ([]model.Server, error) {
	parts := strings.Split(episodeID, "-")
	rawEpID := parts[len(parts)-1]

	srvURL := fmt.Sprintf("https://hianime.at/api/theme/episode/servers?episodeId=%s", rawEpID)
	req, err := http.NewRequestWithContext(ctx, "GET", srvURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	req.Header.Set("X-Requested-With", "XMLHttpRequest")

	resp, err := e.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch anime servers")
	}
	defer resp.Body.Close()

	var ajaxRes hianimeAjaxResponse
	if err := json.NewDecoder(resp.Body).Decode(&ajaxRes); err != nil {
		return nil, err
	}

	reSrv := regexp.MustCompile(`data-type="([^"]*)"[\s\S]*?data-server-name="([^"]*)"[\s\S]*?data-hash="([^"]*)"`)
	matches := reSrv.FindAllStringSubmatch(ajaxRes.HTML, -1)

	var primary []model.Server
	var secondary []model.Server

	for _, m := range matches {
		dtype := strings.ToUpper(m[1])
		sname := m[2]
		dhash := m[3]

		srv := model.Server{
			ID:   fmt.Sprintf("anime-srv-%s-%s-%s", rawEpID, m[1], dhash),
			Name: fmt.Sprintf("[%s] %s (1080p HD)", dtype, sname),
		}

		if strings.EqualFold(sname, "ZokoAnime") {
			primary = append(primary, srv)
		} else {
			secondary = append(secondary, srv)
		}
	}

	// Always place ZokoAnime first since it decrypts directly via XOR
	return append(primary, secondary...), nil
}

// GetStream decodes the ZokoAnime / HiAnime player and extracts direct master .m3u8 and subtitles
func (e *AnimeEngine) GetStream(ctx context.Context, serverID string) (*model.StreamResult, error) {
	parts := strings.Split(serverID, "-")
	if len(parts) < 5 {
		return nil, fmt.Errorf("invalid anime server ID")
	}
	rawEpID := parts[2]
	dhash := parts[len(parts)-1]

	embedBytes, err := base64.StdEncoding.DecodeString(dhash)
	if err != nil {
		return nil, fmt.Errorf("failed to decode embed hash: %w", err)
	}
	embedURL := string(embedBytes)

	// If the embed is not zokoanime, try to find the zokoanime server for this episode
	if !strings.Contains(embedURL, "zokoanime.video") {
		servers, err := e.GetServers(ctx, fmt.Sprintf("anime-ep-tmp-%s", rawEpID))
		if err == nil {
			for _, s := range servers {
				if strings.Contains(s.Name, "ZokoAnime") {
					partsZoko := strings.Split(s.ID, "-")
					zokoHash := partsZoko[len(partsZoko)-1]
					if b, err := base64.StdEncoding.DecodeString(zokoHash); err == nil {
						embedURL = string(b)
						break
					}
				}
			}
		}
	}

	reqEmbed, err := http.NewRequestWithContext(ctx, "GET", embedURL, nil)
	if err != nil {
		return nil, err
	}
	reqEmbed.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	reqEmbed.Header.Set("Referer", "https://hianime.at/")

	respEmbed, err := e.client.Do(reqEmbed)
	if err != nil || respEmbed.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch anime embed")
	}
	defer respEmbed.Body.Close()

	bodyEmbed, err := io.ReadAll(respEmbed.Body)
	if err != nil {
		return nil, err
	}
	embedHTML := string(bodyEmbed)

	reBlob := regexp.MustCompile(`window\.__P\s*=\s*"([^"]*)"`)
	blobMatches := reBlob.FindStringSubmatch(embedHTML)
	if len(blobMatches) < 2 {
		return nil, fmt.Errorf("encrypted stream blob not found in embed")
	}

	rawBytes, err := base64.StdEncoding.DecodeString(blobMatches[1])
	if err != nil {
		return nil, fmt.Errorf("failed to decode stream blob: %w", err)
	}

	xorKey := []byte("otaku-embed-v1")
	decrypted := make([]byte, len(rawBytes))
	for i, b := range rawBytes {
		decrypted[i] = b ^ xorKey[i%len(xorKey)]
	}

	var cfg zokoConfig
	if err := json.Unmarshal(decrypted, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse decrypted player json: %w", err)
	}

	if cfg.Src == "" {
		return nil, fmt.Errorf("no stream URL in decrypted player config")
	}

	var sources []model.Source
	sources = append(sources, model.Source{
		URL:     cfg.Src,
		Quality: "1080p Master HLS (HiAnime / Ani-Cli)",
		IsM3U8:  true,
	})

	var subtitles []model.Subtitle
	for _, s := range cfg.Subtitles {
		subtitles = append(subtitles, model.Subtitle{
			URL:  s.Src,
			Lang: s.Label,
		})
	}
	if len(subtitles) == 0 {
		subtitles = append(subtitles, model.Subtitle{URL: "", Lang: "English (Default)"})
	}

	headers := map[string]string{
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer":    "https://zokoanime.video/",
	}

	return &model.StreamResult{
		Sources:   sources,
		Subtitles: subtitles,
		Headers:   headers,
	}, nil
}
