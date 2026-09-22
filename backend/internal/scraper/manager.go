package scraper

import (
	"context"
	"strings"
	"time"

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

	return &Manager{
		catalogEngine:  ce,
		videoEngine:    ve,
		subtitleEngine: se,
		audioEngine:    ae,
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

func (m *Manager) Search(query string) ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	results, err := m.catalogEngine.Search(ctx, query)
	if err != nil {
		results = []MediaItem{}
	}

	seen := make(map[string]bool)
	var combined []MediaItem
	for _, it := range results {
		if !seen[it.ID] {
			seen[it.ID] = true
			combined = append(combined, it)
		}
	}

	if m.demo != nil {
		demoRes, _ := m.demo.Search(query)
		for _, it := range demoRes {
			if !seen[it.ID] {
				seen[it.ID] = true
				combined = append(combined, it)
			}
		}
	}

	// Non-blocking query to FlixHQ
	if m.flixhq != nil {
		ch := make(chan []MediaItem, 1)
		go func() {
			items, _ := m.flixhq.Search(query)
			ch <- items
		}()

		select {
		case items := <-ch:
			for _, it := range items {
				if !seen[it.ID] {
					seen[it.ID] = true
					combined = append(combined, it)
				}
			}
		case <-time.After(1200 * time.Millisecond):
			// Timeout FlixHQ gracefully
		}
	}

	return combined, nil
}

func (m *Manager) GetTrending() ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	results, err := m.catalogEngine.GetTrending(ctx)
	if err != nil {
		results = []MediaItem{}
	}

	seen := make(map[string]bool)
	var combined []MediaItem
	for _, it := range results {
		if !seen[it.ID] {
			seen[it.ID] = true
			combined = append(combined, it)
		}
	}

	if m.demo != nil {
		demoTrending, _ := m.demo.GetTrending()
		for _, it := range demoTrending {
			if !seen[it.ID] {
				seen[it.ID] = true
				combined = append(combined, it)
			}
		}
	}

	// Non-blocking query to FlixHQ
	if m.flixhq != nil {
		ch := make(chan []MediaItem, 1)
		go func() {
			items, _ := m.flixhq.GetTrending()
			ch <- items
		}()

		select {
		case items := <-ch:
			for _, it := range items {
				if !seen[it.ID] {
					seen[it.ID] = true
					combined = append(combined, it)
				}
			}
		case <-time.After(1200 * time.Millisecond):
			// Timeout FlixHQ gracefully
		}
	}

	return combined, nil
}

func (m *Manager) GetDetails(id string) (*MediaDetails, error) {
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

func (m *Manager) GetServers(episodeId string) ([]Server, error) {
	if strings.HasPrefix(episodeId, "demo-") {
		return m.demo.GetServers(episodeId)
	}
	if strings.HasPrefix(episodeId, "tmdb-") {
		return m.videoEngine.GetServers(episodeId, "")
	}
	return m.flixhq.GetServers(episodeId)
}

func (m *Manager) GetServersWithTitle(episodeId string, title string) ([]Server, error) {
	if strings.HasPrefix(episodeId, "demo-") {
		return m.demo.GetServers(episodeId)
	}
	if strings.HasPrefix(episodeId, "tmdb-") {
		return m.videoEngine.GetServers(episodeId, title)
	}
	return m.flixhq.GetServers(episodeId)
}

func (m *Manager) GetStream(serverId string) (*StreamResult, error) {
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	if strings.HasPrefix(serverId, "tmdb-") {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		stream, err := m.videoEngine.GetStream(ctx, serverId, "")
		if err != nil {
			return nil, err
		}

		if len(stream.Subtitles) == 0 {
			subs, _ := m.subtitleEngine.GetSubtitles(ctx, serverId, "")
			stream.Subtitles = subs
		}

		return stream, nil
	}
	return m.flixhq.GetStream(serverId)
}

func (m *Manager) GetStreamWithTitle(serverId string, title string) (*StreamResult, error) {
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	if strings.HasPrefix(serverId, "tmdb-") {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		stream, err := m.videoEngine.GetStream(ctx, serverId, title)
		if err != nil {
			return nil, err
		}

		if len(stream.Subtitles) == 0 {
			subs, _ := m.subtitleEngine.GetSubtitles(ctx, serverId, title)
			stream.Subtitles = subs
		}

		return stream, nil
	}
	return m.flixhq.GetStream(serverId)
}
