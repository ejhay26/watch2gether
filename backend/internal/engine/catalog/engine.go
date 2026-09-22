package catalog

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/engine/video"
	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type CatalogEngine struct {
	archiveProvider *video.ArchiveProvider
	apiKeys         []string
	keyIndex        int
	baseURL         string
	imageBase       string
	client          *http.Client
}

func NewCatalogEngine(archiveProvider *video.ArchiveProvider, apiKeys []string) *CatalogEngine {
	if len(apiKeys) == 0 {
		apiKeys = []string{
			"844dba0bfd8f3a4f3799f6130ef9e335",
			"e9e9d8da18ae29fc430845952232787c",
			"4113f36a3dce79e4deda2209210e3060",
		}
	}
	return &CatalogEngine{
		archiveProvider: archiveProvider,
		apiKeys:         apiKeys,
		keyIndex:        0,
		baseURL:         "https://api.themoviedb.org/3",
		imageBase:       "https://image.tmdb.org/t/p/w500",
		client: &http.Client{
			Timeout: 6 * time.Second,
		},
	}
}

func (c *CatalogEngine) getKey() string {
	if len(c.apiKeys) == 0 {
		return "844dba0bfd8f3a4f3799f6130ef9e335"
	}
	return c.apiKeys[c.keyIndex%len(c.apiKeys)]
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

func (c *CatalogEngine) GetTrending(ctx context.Context) ([]model.MediaItem, error) {
	var items []model.MediaItem
	seen := make(map[string]bool)

	// 1. Featured playable films first so users immediately see guaranteed playable films!
	for _, vf := range c.archiveProvider.GetAllFilms() {
		id := fmt.Sprintf("tmdb-movie-%s", vf.TMDBID)
		seen[id] = true
		items = append(items, model.MediaItem{
			ID:           id,
			Title:        vf.Title,
			Type:         model.MediaTypeMovie,
			Poster:       vf.Poster,
			Banner:       vf.Banner,
			Year:         vf.Year,
			Rating:       vf.Rating,
			RatingSource: "TMDB",
			Quality:      "1080p HD",
			Duration:     vf.Duration,
			Overview:     vf.Overview,
		})
	}

	// 2. Fetch TMDB trending
	endpoint := fmt.Sprintf("%s/trending/all/day?api_key=%s", c.baseURL, c.getKey())
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err == nil {
		resp, err := c.client.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var res tmdbListResponse
			if err := json.NewDecoder(resp.Body).Decode(&res); err == nil {
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

					mType := model.MediaTypeMovie
					if item.MediaType == "tv" {
						mType = model.MediaTypeTV
					}

					id := fmt.Sprintf("tmdb-%s-%d", mType, item.ID)
					if seen[id] {
						continue
					}
					seen[id] = true

					poster := ""
					if item.PosterPath != "" {
						poster = c.imageBase + item.PosterPath
					} else {
						poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
					}

					banner := poster
					if item.BackdropPath != "" {
						banner = c.imageBase + item.BackdropPath
					}

					year := item.ReleaseDate
					if year == "" {
						year = item.FirstAirDate
					}
					if len(year) >= 4 {
						year = year[:4]
					}

					rating := "7.5"
					if item.VoteAverage > 0 {
						rating = fmt.Sprintf("%.1f", item.VoteAverage)
					}

					overview := item.Overview
					if overview == "" {
						overview = fmt.Sprintf("Stream %s on WatchHub.", title)
					}

					items = append(items, model.MediaItem{
						ID:           id,
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
			}
		}
	}

	return items, nil
}

func (c *CatalogEngine) Search(ctx context.Context, query string) ([]model.MediaItem, error) {
	var items []model.MediaItem
	seen := make(map[string]bool)

	cleanQ := strings.ToLower(strings.TrimSpace(query))
	// 1. Search verified archive films
	for _, vf := range c.archiveProvider.GetAllFilms() {
		if strings.Contains(strings.ToLower(vf.Title), cleanQ) {
			id := fmt.Sprintf("tmdb-movie-%s", vf.TMDBID)
			seen[id] = true
			items = append(items, model.MediaItem{
				ID:           id,
				Title:        vf.Title,
				Type:         model.MediaTypeMovie,
				Poster:       vf.Poster,
				Banner:       vf.Banner,
				Year:         vf.Year,
				Rating:       vf.Rating,
				RatingSource: "TMDB",
				Quality:      "1080p HD",
				Duration:     vf.Duration,
				Overview:     vf.Overview,
			})
		}
	}

	// 2. Search TMDB
	endpoint := fmt.Sprintf("%s/search/multi?api_key=%s&query=%s", c.baseURL, c.getKey(), url.QueryEscape(query))
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err == nil {
		resp, err := c.client.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var res tmdbListResponse
			if err := json.NewDecoder(resp.Body).Decode(&res); err == nil {
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

					mType := model.MediaTypeMovie
					if item.MediaType == "tv" {
						mType = model.MediaTypeTV
					}

					id := fmt.Sprintf("tmdb-%s-%d", mType, item.ID)
					if seen[id] {
						continue
					}
					seen[id] = true

					poster := ""
					if item.PosterPath != "" {
						poster = c.imageBase + item.PosterPath
					} else {
						poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
					}

					banner := poster
					if item.BackdropPath != "" {
						banner = c.imageBase + item.BackdropPath
					}

					year := item.ReleaseDate
					if year == "" {
						year = item.FirstAirDate
					}
					if len(year) >= 4 {
						year = year[:4]
					}

					rating := "7.5"
					if item.VoteAverage > 0 {
						rating = fmt.Sprintf("%.1f", item.VoteAverage)
					}

					items = append(items, model.MediaItem{
						ID:           id,
						Title:        title,
						Type:         mType,
						Poster:       poster,
						Banner:       banner,
						Year:         year,
						Rating:       rating,
						RatingSource: "TMDB",
						Quality:      "1080p HD",
						Overview:     item.Overview,
					})
				}
			}
		}
	}

	return items, nil
}

func (c *CatalogEngine) GetDetails(ctx context.Context, id string) (*model.MediaDetails, error) {
	// Check if in archive provider
	if vf, found := c.archiveProvider.Match(id, ""); found {
		return &model.MediaDetails{
			MediaItem: model.MediaItem{
				ID:           fmt.Sprintf("tmdb-movie-%s", vf.TMDBID),
				Title:        vf.Title,
				Type:         model.MediaTypeMovie,
				Poster:       vf.Poster,
				Banner:       vf.Banner,
				Year:         vf.Year,
				Rating:       vf.Rating,
				RatingSource: "TMDB",
				Quality:      "1080p HD",
				Duration:     vf.Duration,
				Overview:     vf.Overview,
			},
			Genres:  []string{"Classic", "Drama", "Featured"},
			Seasons: []int{},
		}, nil
	}

	parts := strings.Split(id, "-")
	if len(parts) < 3 {
		return nil, fmt.Errorf("invalid tmdb id format: %s", id)
	}

	mType := parts[1]
	tmdbID := parts[2]

	endpoint := fmt.Sprintf("%s/%s/%s?api_key=%s", c.baseURL, mType, tmdbID, c.getKey())
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.client.Do(req)
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
		poster = c.imageBase + detailsRaw.PosterPath
	} else {
		poster = "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80"
	}

	banner := poster
	if detailsRaw.BackdropPath != "" {
		banner = c.imageBase + detailsRaw.BackdropPath
	}

	rating := "7.5"
	if detailsRaw.VoteAverage > 0 {
		rating = fmt.Sprintf("%.1f", detailsRaw.VoteAverage)
	}

	return &model.MediaDetails{
		MediaItem: model.MediaItem{
			ID:           id,
			Title:        title,
			Type:         model.MediaType(mType),
			Poster:       poster,
			Banner:       banner,
			Year:         year,
			Rating:       rating,
			RatingSource: "TMDB",
			Quality:      "1080p HD",
			Duration:     duration,
			Overview:     detailsRaw.Overview,
		},
		Genres:  genres,
		Seasons: seasons,
	}, nil
}

func (c *CatalogEngine) GetEpisodes(ctx context.Context, id string, season int) ([]model.Episode, error) {
	parts := strings.Split(id, "-")
	if len(parts) < 3 {
		return []model.Episode{
			{
				ID:       fmt.Sprintf("%s-ep1", id),
				Number:   1,
				Season:   1,
				Title:    "Full Movie",
				Overview: "Play feature presentation.",
			},
		}, nil
	}

	mType := parts[1]
	tmdbID := parts[2]

	if mType == "movie" {
		return []model.Episode{
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
	endpoint := fmt.Sprintf("%s/tv/%s/season/%d?api_key=%s", c.baseURL, tmdbID, season, c.getKey())
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.client.Do(req)
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

	var episodes []model.Episode
	for _, ep := range seasonData.Episodes {
		name := ep.Name
		if name == "" {
			name = fmt.Sprintf("Episode %d", ep.EpisodeNumber)
		}
		overview := ep.Overview
		if overview == "" {
			overview = fmt.Sprintf("Episode %d of Season %d.", ep.EpisodeNumber, season)
		}
		episodes = append(episodes, model.Episode{
			ID:       fmt.Sprintf("%s-s%d-e%d", id, season, ep.EpisodeNumber),
			Number:   ep.EpisodeNumber,
			Season:   season,
			Title:    name,
			Overview: overview,
		})
	}

	if len(episodes) == 0 {
		episodes = append(episodes, model.Episode{
			ID:       fmt.Sprintf("%s-s%d-e1", id, season),
			Number:   1,
			Season:   season,
			Title:    "Episode 1",
			Overview: "Premiere episode.",
		})
	}

	return episodes, nil
}
