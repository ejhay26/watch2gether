package scraper

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

type FlixHQScraper struct {
	BaseURL    string
	Client     *http.Client
	UserAgent  string
}

func NewFlixHQScraper(baseURL string) *FlixHQScraper {
	if baseURL == "" {
		baseURL = "https://flixhq.to"
	}
	return &FlixHQScraper{
		BaseURL: baseURL,
		Client: &http.Client{
			Timeout: 12 * time.Second,
		},
		UserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
	}
}

func (s *FlixHQScraper) makeRequest(method, endpoint string, body io.Reader) (*http.Response, error) {
	reqURL := endpoint
	if !strings.HasPrefix(endpoint, "http://") && !strings.HasPrefix(endpoint, "https://") {
		reqURL = s.BaseURL + endpoint
	}

	req, err := http.NewRequest(method, reqURL, body)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", s.UserAgent)
	req.Header.Set("X-Requested-With", "XMLHttpRequest")
	req.Header.Set("Referer", s.BaseURL)

	return s.Client.Do(req)
}

func (s *FlixHQScraper) Search(query string) ([]MediaItem, error) {
	escaped := url.PathEscape(strings.ReplaceAll(query, " ", "-"))
	resp, err := s.makeRequest("GET", "/search/"+escaped, nil)
	if err != nil {
		return nil, fmt.Errorf("search request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("search failed with status code %d", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse html: %w", err)
	}

	var results []MediaItem
	doc.Find(".flw-item").Each(func(i int, sel *goquery.Selection) {
		filmDetail := sel.Find(".film-detail")
		filmPoster := sel.Find(".film-poster")

		link, _ := filmPoster.Find("a").Attr("href")
		title := filmDetail.Find(".film-name a").Text()
		poster, _ := filmPoster.Find("img").Attr("data-src")
		if poster == "" {
			poster, _ = filmPoster.Find("img").Attr("src")
		}

		infoSpans := filmDetail.Find(".fd-infor .fdi-item")
		year := ""
		mediaType := MediaTypeMovie
		if infoSpans.Length() > 0 {
			infoSpans.Each(func(j int, item *goquery.Selection) {
				txt := strings.TrimSpace(item.Text())
				if strings.EqualFold(txt, "TV") {
					mediaType = MediaTypeTV
				} else if len(txt) == 4 && (strings.HasPrefix(txt, "19") || strings.HasPrefix(txt, "20")) {
					year = txt
				}
			})
		}

		id := strings.TrimPrefix(link, "/")
		if id != "" && title != "" {
			results = append(results, MediaItem{
				ID:     id,
				Title:  strings.TrimSpace(title),
				Type:   mediaType,
				Poster: poster,
				Year:   year,
			})
		}
	})

	return results, nil
}

func (s *FlixHQScraper) GetTrending() ([]MediaItem, error) {
	resp, err := s.makeRequest("GET", "/home", nil)
	if err != nil {
		return nil, fmt.Errorf("trending request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("trending failed with status code %d", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse html: %w", err)
	}

	var results []MediaItem
	doc.Find("#trending-movies .flw-item, #trending-tv .flw-item").Each(func(i int, sel *goquery.Selection) {
		filmDetail := sel.Find(".film-detail")
		filmPoster := sel.Find(".film-poster")

		link, _ := filmPoster.Find("a").Attr("href")
		title := filmDetail.Find(".film-name a").Text()
		poster, _ := filmPoster.Find("img").Attr("data-src")
		if poster == "" {
			poster, _ = filmPoster.Find("img").Attr("src")
		}

		mediaType := MediaTypeMovie
		if strings.Contains(link, "/tv/") {
			mediaType = MediaTypeTV
		}

		id := strings.TrimPrefix(link, "/")
		if id != "" && title != "" {
			results = append(results, MediaItem{
				ID:     id,
				Title:  strings.TrimSpace(title),
				Type:   mediaType,
				Poster: poster,
			})
		}
	})

	return results, nil
}

func (s *FlixHQScraper) GetDetails(id string) (*MediaDetails, error) {
	resp, err := s.makeRequest("GET", "/"+id, nil)
	if err != nil {
		return nil, fmt.Errorf("details request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("details failed with status code %d", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse html: %w", err)
	}

	title := strings.TrimSpace(doc.Find(".heading-name a").Text())
	poster, _ := doc.Find(".film-poster img").Attr("src")
	overview := strings.TrimSpace(doc.Find(".description").Text())

	mediaType := MediaTypeMovie
	if strings.Contains(id, "/tv/") {
		mediaType = MediaTypeTV
	}

	var genres []string
	doc.Find(".elements .row-line:contains(\"Genre\") a").Each(func(i int, sel *goquery.Selection) {
		genres = append(genres, strings.TrimSpace(sel.Text()))
	})

	details := &MediaDetails{
		MediaItem: MediaItem{
			ID:       id,
			Title:    title,
			Type:     mediaType,
			Poster:   poster,
			Overview: overview,
		},
		Genres: genres,
	}

	return details, nil
}

func (s *FlixHQScraper) GetEpisodes(id string, season int) ([]Episode, error) {
	// For movies, FlixHQ movie ID provides 1 default episode or stream target
	parts := strings.Split(id, "-")
	movieID := parts[len(parts)-1]

	endpoint := fmt.Sprintf("/ajax/movie/episodes/%s", movieID)
	if strings.Contains(id, "tv") {
		endpoint = fmt.Sprintf("/ajax/v2/season/episodes/%s", movieID)
	}

	resp, err := s.makeRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var payload struct {
		HTML string `json:"html"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(payload.HTML))
	if err != nil {
		return nil, err
	}

	var episodes []Episode
	doc.Find(".nav-item a, .eps-item").Each(func(i int, sel *goquery.Selection) {
		dataID, _ := sel.Attr("data-id")
		title := sel.AttrOr("title", sel.Text())
		if dataID != "" {
			episodes = append(episodes, Episode{
				ID:     dataID,
				Number: i + 1,
				Season: season,
				Title:  strings.TrimSpace(title),
			})
		}
	})

	return episodes, nil
}

func (s *FlixHQScraper) GetServers(episodeId string) ([]Server, error) {
	resp, err := s.makeRequest("GET", fmt.Sprintf("/ajax/episode/servers/%s", episodeId), nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var payload struct {
		HTML string `json:"html"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(payload.HTML))
	if err != nil {
		return nil, err
	}

	var servers []Server
	doc.Find(".nav-item a").Each(func(i int, sel *goquery.Selection) {
		dataID, _ := sel.Attr("data-id")
		name := strings.TrimSpace(sel.Text())
		if dataID != "" {
			servers = append(servers, Server{
				ID:   dataID,
				Name: name,
			})
		}
	})

	return servers, nil
}

func (s *FlixHQScraper) GetStream(serverId string) (*StreamResult, error) {
	resp, err := s.makeRequest("GET", fmt.Sprintf("/ajax/episode/sources/%s", serverId), nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var payload struct {
		Type string `json:"type"`
		Link string `json:"link"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}

	if payload.Link == "" {
		return nil, fmt.Errorf("no stream embed link returned")
	}

	// Extract embed stream sources from embed link (e.g. Rabbitstream / Megacloud)
	return s.extractEmbedSources(payload.Link)
}

func (s *FlixHQScraper) extractEmbedSources(embedURL string) (*StreamResult, error) {
	parsedURL, err := url.Parse(embedURL)
	if err != nil {
		return nil, err
	}

	// Megacloud / Rabbitstream /embed-4/<id> or /embed-2/<id>
	pathParts := strings.Split(strings.Trim(parsedURL.Path, "/"), "/")
	embedID := pathParts[len(pathParts)-1]
	sourceURL := fmt.Sprintf("%s://%s/ajax/embed-4/getSources?id=%s", parsedURL.Scheme, parsedURL.Host, embedID)

	req, err := http.NewRequest("GET", sourceURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-Requested-With", "XMLHttpRequest")
	req.Header.Set("Referer", embedURL)
	req.Header.Set("User-Agent", s.UserAgent)

	resp, err := s.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var res struct {
		Sources   json.RawMessage `json:"sources"`
		Tracks    []struct {
			File  string `json:"file"`
			Label string `json:"label"`
			Kind  string `json:"kind"`
		} `json:"tracks"`
		Encrypted bool `json:"encrypted"`
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(bodyBytes, &res); err != nil {
		return nil, fmt.Errorf("invalid json response from embed: %w", err)
	}

	var sources []Source
	// Check if sources is an array or encrypted string
	var directSources []struct {
		File string `json:"file"`
		Type string `json:"type"`
	}
	if err := json.Unmarshal(res.Sources, &directSources); err == nil && len(directSources) > 0 {
		for _, s := range directSources {
			sources = append(sources, Source{
				URL:     s.File,
				Quality: "auto",
				IsM3U8:  strings.Contains(s.File, ".m3u8"),
			})
		}
	} else {
		// Encrypted source payload string
		var encryptedStr string
		if err := json.Unmarshal(res.Sources, &encryptedStr); err == nil && encryptedStr != "" {
			// Decryption fallback
			decrypted, err := OpenSSLDecrypt([]byte(encryptedStr), "megacloud")
			if err == nil {
				var decSources []struct {
					File string `json:"file"`
					Type string `json:"type"`
				}
				if err := json.Unmarshal(decrypted, &decSources); err == nil {
					for _, s := range decSources {
						sources = append(sources, Source{
							URL:     s.File,
							Quality: "auto",
							IsM3U8:  strings.Contains(s.File, ".m3u8"),
						})
					}
				}
			}
		}
	}

	var subs []Subtitle
	for _, trk := range res.Tracks {
		if trk.Kind == "captions" || trk.Kind == "subtitles" {
			subs = append(subs, Subtitle{
				URL:  trk.File,
				Lang: trk.Label,
			})
		}
	}

	return &StreamResult{
		Sources:   sources,
		Subtitles: subs,
		Headers: map[string]string{
			"Referer":    embedURL,
			"User-Agent": s.UserAgent,
		},
	}, nil
}
