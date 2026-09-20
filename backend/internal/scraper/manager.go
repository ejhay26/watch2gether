package scraper

import (
	"fmt"
	"strings"
	"time"
)

type Manager struct {
	flixhq *FlixHQScraper
	demo   *DemoProvider
}

func NewManager(flixhqURL string) *Manager {
	s := NewFlixHQScraper(flixhqURL)
	s.Client.Timeout = 6 * time.Second
	return &Manager{
		flixhq: s,
		demo:   NewDemoProvider(),
	}
}

func NewManagerWithProviders(flixhq *FlixHQScraper, demo *DemoProvider) *Manager {
	return &Manager{
		flixhq: flixhq,
		demo:   demo,
	}
}

func (m *Manager) Search(query string) ([]MediaItem, error) {
	demoResults, _ := m.demo.Search(query)

	if strings.HasPrefix(strings.ToLower(query), "demo") {
		return demoResults, nil
	}

	flixResults, err := m.flixhq.Search(query)
	if err != nil {
		if len(demoResults) > 0 {
			return demoResults, nil
		}
		return nil, fmt.Errorf("search failed: %w", err)
	}

	return append(demoResults, flixResults...), nil
}

func (m *Manager) GetTrending() ([]MediaItem, error) {
	demoTrending, _ := m.demo.GetTrending()
	flixTrending, err := m.flixhq.GetTrending()
	if err != nil || len(flixTrending) == 0 {
		return demoTrending, nil
	}

	return append(demoTrending, flixTrending...), nil
}

func (m *Manager) GetDetails(id string) (*MediaDetails, error) {
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetDetails(id)
	}
	return m.flixhq.GetDetails(id)
}

func (m *Manager) GetEpisodes(id string, season int) ([]Episode, error) {
	if strings.HasPrefix(id, "demo-") {
		return m.demo.GetEpisodes(id, season)
	}
	return m.flixhq.GetEpisodes(id, season)
}

func (m *Manager) GetServers(episodeId string) ([]Server, error) {
	if strings.HasPrefix(episodeId, "demo-") {
		return m.demo.GetServers(episodeId)
	}
	return m.flixhq.GetServers(episodeId)
}

func (m *Manager) GetStream(serverId string) (*StreamResult, error) {
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	return m.flixhq.GetStream(serverId)
}
