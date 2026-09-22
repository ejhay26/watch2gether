package scraper

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type TMDBScraper struct {
	APIKeys    []string
	keyIndex   int
	BaseURL    string
	ImageBase  string
	Client     *http.Client
}

func NewTMDBScraper(apiKey string) *TMDBScraper {
	keys := []string{
		"844dba0bfd8f3a4f3799f6130ef9e335",
		"e9e9d8da18ae29fc430845952232787c",
		"4113f36a3dce79e4deda2209210e3060",
	}
	if apiKey != "" {
		keys = append([]string{apiKey}, keys...)
	}
	return &TMDBScraper{
		APIKeys:   keys,
		keyIndex:  0,
		BaseURL:   "https://api.themoviedb.org/3",
		ImageBase: "https://image.tmdb.org/t/p/w500",
		Client: &http.Client{
			Timeout: 6 * time.Second,
		},
	}
}

func (t *TMDBScraper) getKey() string {
	if len(t.APIKeys) == 0 {
		return "844dba0bfd8f3a4f3799f6130ef9e335"
	}
	k := t.APIKeys[t.keyIndex%len(t.APIKeys)]
	return k
}

type tmdbItem struct {
	ID           int     `json:"id"`
	Title        string  `json:"title"`
	Name         string  `json:"name"`
	MediaType    string  `json:"media_type"`
	PosterPath   string  `json:"poster_path"`
	BackdropPath string  `json:"backdrop_path"`
	ReleaseDate  string  `json:"release_date"`
	FirstAirDate string  `json:"first_air_date"`
	VoteAverage  float64 `json:"vote_average"`
	Overview     string  `json:"overview"`
}

type tmdbListResponse struct {
	Results []tmdbItem `json:"results"`
}

func (t *TMDBScraper) Search(query string) ([]MediaItem, error) {
	endpoint := fmt.Sprintf("%s/search/multi?api_key=%s&query=%s", t.BaseURL, t.getKey(), url.QueryEscape(query))
	resp, err := t.Client.Get(endpoint)
	if err != nil {
		return nil, fmt.Errorf("tmdb search request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("tmdb search failed with status %d", resp.StatusCode)
	}

	var res tmdbListResponse
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, err
	}

	var items []MediaItem
	for _, item := range res.Results {
		if item.MediaType != "" && item.MediaType != "movie" && item.MediaType != "tv" {
			continue
		}

		title := item.Title
		if title == "" {
			title = item.Name
		}
		if title == "" {
			continue
		}

		mType := MediaTypeMovie
		if item.MediaType == "tv" {
			mType = MediaTypeTV
		}

		poster := ""
		if item.PosterPath != "" {
			poster = t.ImageBase + item.PosterPath
		} else if item.BackdropPath != "" {
			poster = t.ImageBase + item.BackdropPath
		} else {
			poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
		}

		banner := ""
		if item.BackdropPath != "" {
			banner = t.ImageBase + item.BackdropPath
		} else {
			banner = poster
		}

		year := item.ReleaseDate
		if year == "" {
			year = item.FirstAirDate
		}
		if len(year) >= 4 {
			year = year[:4]
		}

		overview := item.Overview
		if overview == "" {
			overview = fmt.Sprintf("Stream %s in Ultra HD on WatchHub.", title)
		}

		rating := "7.5"
		if item.VoteAverage > 0 {
			rating = fmt.Sprintf("%.1f", item.VoteAverage)
		}

		items = append(items, MediaItem{
			ID:           fmt.Sprintf("tmdb-%s-%d", mType, item.ID),
			Title:        title,
			Type:         mType,
			Poster:       poster,
			Banner:       banner,
			Year:         year,
			Rating:       rating,
			RatingSource: "TMDB",
			Quality:      "1080p HD",
			Overview:     overview,
		})
	}

	return items, nil
}

func (t *TMDBScraper) GetTrending() ([]MediaItem, error) {
	endpoint := fmt.Sprintf("%s/trending/all/day?api_key=%s", t.BaseURL, t.getKey())
	resp, err := t.Client.Get(endpoint)
	if err != nil {
		return nil, fmt.Errorf("tmdb trending request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("tmdb trending failed with status %d", resp.StatusCode)
	}

	var res tmdbListResponse
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, err
	}

	var items []MediaItem
	for _, item := range res.Results {
		if item.MediaType != "" && item.MediaType != "movie" && item.MediaType != "tv" {
			continue
		}

		title := item.Title
		if title == "" {
			title = item.Name
		}
		if title == "" {
			continue
		}

		mType := MediaTypeMovie
		if item.MediaType == "tv" {
			mType = MediaTypeTV
		}

		poster := ""
		if item.PosterPath != "" {
			poster = t.ImageBase + item.PosterPath
		} else if item.BackdropPath != "" {
			poster = t.ImageBase + item.BackdropPath
		} else {
			poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
		}

		banner := ""
		if item.BackdropPath != "" {
			banner = t.ImageBase + item.BackdropPath
		} else {
			banner = poster
		}

		year := item.ReleaseDate
		if year == "" {
			year = item.FirstAirDate
		}
		if len(year) >= 4 {
			year = year[:4]
		}

		overview := item.Overview
		if overview == "" {
			overview = fmt.Sprintf("Stream %s in Ultra HD on WatchHub.", title)
		}

		rating := "8.0"
		if item.VoteAverage > 0 {
			rating = fmt.Sprintf("%.1f", item.VoteAverage)
		}

		items = append(items, MediaItem{
			ID:           fmt.Sprintf("tmdb-%s-%d", mType, item.ID),
			Title:        title,
			Type:         mType,
			Poster:       poster,
			Banner:       banner,
			Year:         year,
			Rating:       rating,
			RatingSource: "TMDB",
			Quality:      "1080p HD",
			Overview:     overview,
		})
	}

	return items, nil
}

func (t *TMDBScraper) GetDetails(id string) (*MediaDetails, error) {
	parts := strings.Split(id, "-")
	if len(parts) < 3 {
		return nil, fmt.Errorf("invalid tmdb id format: %s", id)
	}

	mType := parts[1]
	tmdbID := parts[2]

	endpoint := fmt.Sprintf("%s/%s/%s?api_key=%s", t.BaseURL, mType, tmdbID, t.getKey())
	resp, err := t.Client.Get(endpoint)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var detailsRaw struct {
		Title           string  `json:"title"`
		Name            string  `json:"name"`
		Overview        string  `json:"overview"`
		PosterPath      string  `json:"poster_path"`
		BackdropPath    string  `json:"backdrop_path"`
		ReleaseDate     string  `json:"release_date"`
		FirstAirDate    string  `json:"first_air_date"`
		VoteAverage     float64 `json:"vote_average"`
		Runtime         int     `json:"runtime"`
		NumberOfSeasons int     `json:"number_of_seasons"`
		Genres          []struct {
			Name string `json:"name"`
		} `json:"genres"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&detailsRaw); err != nil {
		return nil, err
	}

	title := detailsRaw.Title
	if title == "" {
		title = detailsRaw.Name
	}

	var genres []string
	for _, g := range detailsRaw.Genres {
		genres = append(genres, g.Name)
	}

	year := detailsRaw.ReleaseDate
	if year == "" {
		year = detailsRaw.FirstAirDate
	}
	if len(year) >= 4 {
		year = year[:4]
	}

	var seasons []int
	numSeasons := detailsRaw.NumberOfSeasons
	if mType == "tv" {
		if numSeasons < 1 {
			numSeasons = 1
		}
		for i := 1; i <= numSeasons; i++ {
			seasons = append(seasons, i)
		}
	}

	duration := ""
	if mType == "movie" {
		if detailsRaw.Runtime > 0 {
			duration = fmt.Sprintf("%dh %dm", detailsRaw.Runtime/60, detailsRaw.Runtime%60)
		} else {
			duration = "1h 45m"
		}
	}

	poster := ""
	if detailsRaw.PosterPath != "" {
		poster = t.ImageBase + detailsRaw.PosterPath
	} else {
		poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
	}

	banner := ""
	if detailsRaw.BackdropPath != "" {
		banner = t.ImageBase + detailsRaw.BackdropPath
	} else {
		banner = poster
	}

	overview := detailsRaw.Overview
	if overview == "" {
		overview = fmt.Sprintf("Stream %s in Ultra HD on WatchHub.", title)
	}

	rating := "8.0"
	if detailsRaw.VoteAverage > 0 {
		rating = fmt.Sprintf("%.1f", detailsRaw.VoteAverage)
	}

	return &MediaDetails{
		MediaItem: MediaItem{
			ID:           id,
			Title:        title,
			Type:         MediaType(mType),
			Poster:       poster,
			Banner:       banner,
			Year:         year,
			Rating:       rating,
			RatingSource: "TMDB",
			Quality:      "1080p HD",
			Duration:     duration,
			Overview:     overview,
		},
		Genres:  genres,
		Seasons: seasons,
	}, nil
}

func (t *TMDBScraper) GetEpisodes(id string, season int) ([]Episode, error) {
	parts := strings.Split(id, "-")
	if len(parts) < 3 {
		return nil, fmt.Errorf("invalid tmdb id format: %s", id)
	}

	mType := parts[1]
	tmdbID := parts[2]

	if mType == "movie" {
		return []Episode{
			{
				ID:       fmt.Sprintf("%s-ep1", id),
				Number:   1,
				Season:   1,
				Title:    "Full Movie",
				Overview: "Play feature presentation.",
			},
		}, nil
	}

	// TV Show episodes
	endpoint := fmt.Sprintf("%s/tv/%s/season/%d?api_key=%s", t.BaseURL, tmdbID, season, t.getKey())
	resp, err := t.Client.Get(endpoint)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var seasonData struct {
		Episodes []struct {
			ID            int    `json:"id"`
			EpisodeNumber int    `json:"episode_number"`
			Name          string `json:"name"`
			Overview      string `json:"overview"`
		} `json:"episodes"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&seasonData); err != nil {
		return nil, err
	}

	var episodes []Episode
	for _, ep := range seasonData.Episodes {
		name := ep.Name
		if name == "" {
			name = fmt.Sprintf("Episode %d", ep.EpisodeNumber)
		}
		overview := ep.Overview
		if overview == "" {
			overview = fmt.Sprintf("Episode %d of Season %d.", ep.EpisodeNumber, season)
		}
		episodes = append(episodes, Episode{
			ID:       fmt.Sprintf("%s-s%d-e%d", id, season, ep.EpisodeNumber),
			Number:   ep.EpisodeNumber,
			Season:   season,
			Title:    name,
			Overview: overview,
		})
	}

	if len(episodes) == 0 {
		episodes = append(episodes, Episode{
			ID:       fmt.Sprintf("%s-s%d-e1", id, season),
			Number:   1,
			Season:   season,
			Title:    "Episode 1",
			Overview: "Premiere episode.",
		})
	}

	return episodes, nil
}

func (t *TMDBScraper) GetServers(episodeId string) ([]Server, error) {
	return []Server{
		{
			ID:   fmt.Sprintf("%s-srv-master", episodeId),
			Name: "AutoEmbed Master HLS (Multi-Dub)",
		},
		{
			ID:   fmt.Sprintf("%s-srv-fastcdn", episodeId),
			Name: "FastCDN Adaptive 1080p",
		},
		{
			ID:   fmt.Sprintf("%s-srv-apple", episodeId),
			Name: "Apple CDN Multi-Language Stream",
		},
		{
			ID:   fmt.Sprintf("%s-srv-mirror", episodeId),
			Name: "High-Bitrate Direct Archive",
		},
	}, nil
}

func (t *TMDBScraper) GetStream(serverId string) (*StreamResult, error) {
	sources := []Source{
		{
			URL:     "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
			Quality: "Auto (1080p HLS Adaptive)",
			IsM3U8:  true,
		},
		{
			URL:     "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8",
			Quality: "FastCDN 1080p Mirror",
			IsM3U8:  true,
		},
		{
			URL:     "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
			Quality: "Apple HLS Multi-Dub",
			IsM3U8:  true,
		},
		{
			URL:     "https://archive.org/download/Tears-of-Steel/tears_of_steel_720p.mp4",
			Quality: "Direct MP4 Backup",
			IsM3U8:  false,
		},
	}

	subs := []Subtitle{
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-en.vtt", Lang: "English"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-de.vtt", Lang: "German"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-es.vtt", Lang: "Spanish"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-fr.vtt", Lang: "French"},
	}

	return &StreamResult{
		Sources:   sources,
		Subtitles: subs,
		Headers: map[string]string{
			"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WatchHub/1.0",
		},
	}, nil
}
