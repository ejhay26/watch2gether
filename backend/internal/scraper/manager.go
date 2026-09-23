package scraper

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/engine/anime"
	"github.com/ejhay26/watch2gether/backend/internal/engine/audio"
	"github.com/ejhay26/watch2gether/backend/internal/engine/catalog"
	"github.com/ejhay26/watch2gether/backend/internal/engine/subtitle"
	"github.com/ejhay26/watch2gether/backend/internal/engine/video"
)

type Manager struct {
	catalogEngine  *catalog.CatalogEngine
	videoEngine    *video.VideoEngine
	subtitleEngine *subtitle.SubtitleEngine
	audioEngine    *audio.AudioEngine
	animeEngine    *anime.AnimeEngine
	demo           *DemoProvider
	flixhq         *FlixHQScraper
}

func NewManager(flixhqURL string) *Manager {
	keys := []string{
		"844dba0bfd8f3a4f3799f6130ef9e335",
		"e9e9d8da18ae29fc430845952232787c",
		"4113f36a3dce79e4deda2209210e3060",
	}
	ve := video.NewVideoEngine(keys)
	ce := catalog.NewCatalogEngine(ve.GetArchiveProvider(), keys)
	se := subtitle.NewSubtitleEngine()
	ae := audio.NewAudioEngine()
	ane := anime.NewAnimeEngine()

	return &Manager{
		catalogEngine:  ce,
		videoEngine:    ve,
		subtitleEngine: se,
		audioEngine:    ae,
		animeEngine:    ane,
		demo:           NewDemoProvider(),
		flixhq:         NewFlixHQScraper(flixhqURL),
	}
}

func NewManagerWithProviders(flixhq *FlixHQScraper, demo *DemoProvider) *Manager {
	mgr := NewManager("")
	mgr.flixhq = flixhq
	mgr.demo = demo
	return mgr
}

func (m *Manager) GetCatalogEngine() *catalog.CatalogEngine {
	return m.catalogEngine
}

func (m *Manager) GetVideoEngine() *video.VideoEngine {
	return m.videoEngine
}

func (m *Manager) GetSubtitleEngine() *subtitle.SubtitleEngine {
	return m.subtitleEngine
}

func (m *Manager) GetAudioEngine() *audio.AudioEngine {
	return m.audioEngine
}

func (m *Manager) GetAnimeEngine() *anime.AnimeEngine {
	return m.animeEngine
}

func (m *Manager) Search(query string) ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	var mu sync.Mutex

	seen := make(map[string]bool)
	var combined []MediaItem

	addItem := func(it MediaItem) {
		mu.Lock()
		defer mu.Unlock()
		if !seen[it.ID] {
			seen[it.ID] = true
			combined = append(combined, it)
		}
	}

	// 1. Search TMDB / Catalog
	wg.Add(1)
	go func() {
		defer wg.Done()
		results, err := m.catalogEngine.Search(ctx, query)
		if err == nil {
			for _, it := range results {
				addItem(it)
			}
		}
	}()

	// 2. Search HiAnime / Ani-Cli (Anime, Cartoons, Series)
	if m.animeEngine != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results, err := m.animeEngine.Search(ctx, query)
			if err == nil {
				for _, it := range results {
					addItem(it)
				}
			}
		}()
	}

	// 3. Search Demo
	if m.demo != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			demoRes, err := m.demo.Search(query)
			if err == nil {
				for _, it := range demoRes {
					addItem(it)
				}
			}
		}()
	}

	// Wait with grace period
	doneCh := make(chan struct{})
	go func() {
		wg.Wait()
		close(doneCh)
	}()

	select {
	case <-doneCh:
	case <-time.After(5 * time.Second):
	}

	return combined, nil
}

func (m *Manager) GetTrending() ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	var mu sync.Mutex

	seen := make(map[string]bool)
	var combined []MediaItem

	addItem := func(it MediaItem) {
		mu.Lock()
		defer mu.Unlock()
		if !seen[it.ID] {
			seen[it.ID] = true
			combined = append(combined, it)
		}
	}

	// 1. TMDB Trending
	wg.Add(1)
	go func() {
		defer wg.Done()
		results, err := m.catalogEngine.GetTrending(ctx)
		if err == nil {
			for _, it := range results {
				addItem(it)
			}
		}
	}()

	// 2. HiAnime Trending (Popular Anime & Animation)
	if m.animeEngine != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results, err := m.animeEngine.GetTrending(ctx)
			if err == nil {
				for _, it := range results {
					addItem(it)
				}
			}
		}()
	}

	// 3. Demo trending
	if m.demo != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			demoRes, err := m.demo.GetTrending()
			if err == nil {
				for _, it := range demoRes {
					addItem(it)
				}
			}
		}()
	}

	doneCh := make(chan struct{})
	go func() {
		wg.Wait()
		close(doneCh)
	}()

	select {
	case <-doneCh:
	case <-time.After(5 * time.Second):
	}

	return combined, nil
}

func (m *Manager) GetDetails(id string) (*MediaDetails, error) {
	if strings.HasPrefix(id, "anime-") {
		ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
		defer cancel()
		return m.animeEngine.GetDetails(ctx, id)
	}
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetDetails(id)
	}
	if strings.HasPrefix(id, "tmdb-") {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return m.catalogEngine.GetDetails(ctx, id)
	}
	return m.flixhq.GetDetails(id)
}

func (m *Manager) GetEpisodes(id string, season int) ([]Episode, error) {
	if strings.HasPrefix(id, "anime-") {
		ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
		defer cancel()
		return m.animeEngine.GetEpisodes(ctx, id)
	}
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetEpisodes(id, season)
	}
	if strings.HasPrefix(id, "tmdb-") {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return m.catalogEngine.GetEpisodes(ctx, id, season)
	}
	return m.flixhq.GetEpisodes(id, season)
}

func (m *Manager) GetRecommendations(id string) ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	if strings.HasPrefix(id, "anime-") {
		return m.animeEngine.GetTrending(ctx)
	}
	return m.catalogEngine.GetRecommendations(ctx, id)
}

func (m *Manager) GetServers(episodeId string) ([]Server, error) {
	return m.GetServersWithTitle(episodeId, "")
}

func (m *Manager) GetServersWithTitle(episodeId string, title string) ([]Server, error) {
	if strings.HasPrefix(episodeId, "anime-") {
		ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
		defer cancel()
		return m.animeEngine.GetServers(ctx, episodeId)
	}
	if strings.HasPrefix(episodeId, "demo-") {
		return m.demo.GetServers(episodeId)
	}
	if strings.HasPrefix(episodeId, "tmdb-") || strings.HasPrefix(episodeId, "movie-") || strings.HasPrefix(episodeId, "archive-") || title != "" || !strings.Contains(episodeId, "flix") {
		srvs, err := m.videoEngine.GetServers(episodeId, title)
		if err == nil && len(srvs) > 0 {
			return srvs, nil
		}
	}
	srvs, err := m.flixhq.GetServers(episodeId)
	if err == nil && len(srvs) > 0 {
		return srvs, nil
	}
	return m.videoEngine.GetServers(episodeId, title)
}

func (m *Manager) GetStream(serverId string) (*StreamResult, error) {
	return m.GetStreamWithTitle(serverId, "")
}

func (m *Manager) GetStreamWithTitle(serverId string, title string) (*StreamResult, error) {
	if strings.HasPrefix(serverId, "anime-") {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		return m.animeEngine.GetStream(ctx, serverId)
	}
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	if strings.HasPrefix(serverId, "tmdb-") || strings.HasPrefix(serverId, "movie-") || strings.Contains(serverId, "-srv-") || strings.HasPrefix(serverId, "archive-") || title != "" || !strings.Contains(serverId, "flix") {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		stream, err := m.videoEngine.GetStream(ctx, serverId, title)
		if err == nil && stream != nil && len(stream.Sources) > 0 {
			if len(stream.Subtitles) == 0 {
				subs, _ := m.subtitleEngine.GetSubtitles(ctx, serverId, title)
				stream.Subtitles = subs
			}
			return stream, nil
		}
	}
	stream, err := m.flixhq.GetStream(serverId)
	if err == nil && stream != nil && len(stream.Sources) > 0 {
		return stream, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	return m.videoEngine.GetStream(ctx, serverId, title)
}
