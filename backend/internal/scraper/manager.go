package scraper

import (
	"strings"
	"time"
)

type Manager struct {
	tmdb   *TMDBScraper
	flixhq *FlixHQScraper
	demo   *DemoProvider
}

func NewManager(flixhqURL string) *Manager {
	return &Manager{
		tmdb:   NewTMDBScraper(""),
		flixhq: NewFlixHQScraper(flixhqURL),
		demo:   NewDemoProvider(),
	}
}

func NewManagerWithProviders(flixhq *FlixHQScraper, demo *DemoProvider) *Manager {
	return &Manager{
		tmdb:   NewTMDBScraper(""),
		flixhq: flixhq,
		demo:   demo,
	}
}

func (m *Manager) Search(query string) ([]MediaItem, error) {
	var combined []MediaItem
	seen := make(map[string]bool)

	addItem := func(items []MediaItem) {
		for _, item := range items {
			if !seen[item.ID] && item.Title != "" {
				seen[item.ID] = true
				combined = append(combined, item)
			}
		}
	}

	// 1. Check Demo items (instant)
	demoResults, _ := m.demo.Search(query)
	addItem(demoResults)

	// 2. Query TMDB (fast, reliable, global catalog)
	tmdbResults, err := m.tmdb.Search(query)
	if err == nil {
		addItem(tmdbResults)
	}

	// 3. Query FlixHQ concurrently with a short timeout so dead mirrors never block
	type flixRes struct {
		items []MediaItem
	}
	ch := make(chan flixRes, 1)
	go func() {
		res, _ := m.flixhq.Search(query)
		ch <- flixRes{items: res}
	}()

	select {
	case r := <-ch:
		addItem(r.items)
	case <-time.After(1500 * time.Millisecond):
		// FlixHQ timed out, continue with TMDB and demo results
	}

	if combined == nil {
		combined = []MediaItem{}
	}
	return combined, nil
}

func (m *Manager) GetTrending() ([]MediaItem, error) {
	var combined []MediaItem
	seen := make(map[string]bool)

	addItem := func(items []MediaItem) {
		for _, item := range items {
			if !seen[item.ID] && item.Title != "" {
				seen[item.ID] = true
				combined = append(combined, item)
			}
		}
	}

	// 1. Fetch TMDB Trending
	tmdbTrending, err := m.tmdb.GetTrending()
	if err == nil && len(tmdbTrending) > 0 {
		addItem(tmdbTrending)
	}

	// 2. Append Open Media Demo Items
	demoTrending, _ := m.demo.GetTrending()
	addItem(demoTrending)

	// 3. Query FlixHQ concurrently with short timeout
	type flixRes struct {
		items []MediaItem
	}
	ch := make(chan flixRes, 1)
	go func() {
		res, _ := m.flixhq.GetTrending()
		ch <- flixRes{items: res}
	}()

	select {
	case r := <-ch:
		addItem(r.items)
	case <-time.After(1500 * time.Millisecond):
		// FlixHQ timed out, continue with TMDB and demo results
	}

	if combined == nil {
		combined = []MediaItem{}
	}
	return combined, nil
}

func (m *Manager) GetDetails(id string) (*MediaDetails, error) {
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetDetails(id)
	}
	if strings.HasPrefix(id, "tmdb-") {
		return m.tmdb.GetDetails(id)
	}
	return m.flixhq.GetDetails(id)
}

func (m *Manager) GetEpisodes(id string, season int) ([]Episode, error) {
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetEpisodes(id, season)
	}
	if strings.HasPrefix(id, "tmdb-") {
		return m.tmdb.GetEpisodes(id, season)
	}
	return m.flixhq.GetEpisodes(id, season)
}

func (m *Manager) GetServers(episodeId string) ([]Server, error) {
	if strings.HasPrefix(episodeId, "demo-") {
		return m.demo.GetServers(episodeId)
	}
	if strings.HasPrefix(episodeId, "tmdb-") {
		return m.tmdb.GetServers(episodeId)
	}
	return m.flixhq.GetServers(episodeId)
}

func (m *Manager) GetStream(serverId string) (*StreamResult, error) {
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	if strings.HasPrefix(serverId, "tmdb-") {
		return m.tmdb.GetStream(serverId)
	}
	return m.flixhq.GetStream(serverId)
}
