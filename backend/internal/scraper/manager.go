package scraper

import (
	"context"
	"regexp"
	"sort"
	"strings"
	"strconv"
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


var yearRegex = regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)

func rankSearchResults(rawQuery string, items []MediaItem) []MediaItem {
	queryLower := strings.ToLower(strings.TrimSpace(rawQuery))
	if queryLower == "" || len(items) == 0 {
		return items
	}

	yearMatch := yearRegex.FindString(queryLower)
	cleanQuery := queryLower
	if yearMatch != "" {
		cleanQuery = strings.TrimSpace(yearRegex.ReplaceAllString(cleanQuery, ""))
	}

	rawWords := strings.Fields(cleanQuery)
	stopWords := map[string]bool{"a": true, "an": true, "the": true, "of": true, "in": true, "on": true, "and": true, "to": true}
	var significantWords []string
	for _, w := range rawWords {
		if len(rawWords) > 1 && stopWords[w] {
			continue
		}
		significantWords = append(significantWords, w)
	}
	if len(significantWords) == 0 {
		significantWords = rawWords
	}

	isExplicitAnimeQuery := strings.Contains(queryLower, "anime") || strings.Contains(queryLower, "manga")

	type scoredItem struct {
		item  MediaItem
		score float64
	}

	scored := make([]scoredItem, len(items))
	for i, it := range items {
		titleLower := strings.ToLower(strings.TrimSpace(it.Title))
		score := 0.0

		// 1. Exact title match
		if titleLower == queryLower || (cleanQuery != "" && titleLower == cleanQuery) {
			score += 1000
		} else if cleanQuery != "" && strings.HasPrefix(titleLower, cleanQuery) {
			score += 500
		} else if cleanQuery != "" && strings.Contains(titleLower, cleanQuery) {
			score += 300
		}

		// 2. Word matching
		matchedWords := 0
		for _, w := range significantWords {
			if strings.Contains(titleLower, w) {
				matchedWords++
				score += 80
			} else {
				score -= 60
			}
		}
		if len(significantWords) > 0 && matchedWords == len(significantWords) {
			score += 200 // All query words found in title
		}

		// 3. Year match
		if yearMatch != "" {
			if it.Year == yearMatch {
				score += 600 // Massive boost for exact year match
			} else if it.Year != "" {
				score -= 150
			}
		}

		// 4. Source / Anime tuning
		isAnime := strings.HasPrefix(it.ID, "anime-")
		if !isExplicitAnimeQuery {
			if !isAnime {
				score += 150 // Boost catalog / mainstream films
			} else {
				// Penalize anime if it does not match all significant words
				if matchedWords < len(significantWords) {
					score -= 300
				}
			}
		}

		// 5. Popularity/Overview bonus
		if it.Poster != "" {
			score += 20
		}
		if it.Overview != "" {
			score += 10
		}

		scored[i] = scoredItem{item: it, score: score}
	}

	sort.SliceStable(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	result := make([]MediaItem, len(scored))
	for i, s := range scored {
		result[i] = s.item
	}
	return result
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

		// 4. Search FlixHQ if configured
	if m.flixhq != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			flixRes, err := m.flixhq.Search(query)
			if err == nil {
				for _, it := range flixRes {
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

	return rankSearchResults(query, combined), nil
}

func (m *Manager) GetTrending() ([]MediaItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	var mu sync.Mutex

	seen := make(map[string]bool)
	var tmdbItems []MediaItem
	var animeItems []MediaItem
	var demoItems []MediaItem

	// 1. TMDB Trending (Mainstream Movies & Series)
	wg.Add(1)
	go func() {
		defer wg.Done()
		results, err := m.catalogEngine.GetTrending(ctx)
		if err == nil {
			mu.Lock()
			for _, it := range results {
				if !seen[it.ID] {
					seen[it.ID] = true
					tmdbItems = append(tmdbItems, it)
				}
			}
			mu.Unlock()
		}
	}()

	// 2. HiAnime Trending (Anime & Animation)
	if m.animeEngine != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results, err := m.animeEngine.GetTrending(ctx)
			if err == nil {
				mu.Lock()
				for _, it := range results {
					if !seen[it.ID] {
						seen[it.ID] = true
						animeItems = append(animeItems, it)
					}
				}
				mu.Unlock()
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
				mu.Lock()
				for _, it := range demoRes {
					if !seen[it.ID] {
						seen[it.ID] = true
						demoItems = append(demoItems, it)
					}
				}
				mu.Unlock()
			}
		}()
	}

	// 4. FlixHQ trending if configured
	if m.flixhq != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			flixRes, err := m.flixhq.GetTrending()
			if err == nil {
				mu.Lock()
				for _, it := range flixRes {
					if !seen[it.ID] {
						seen[it.ID] = true
						tmdbItems = append(tmdbItems, it)
					}
				}
				mu.Unlock()
			}
		}()
	}

		// 4. FlixHQ trending if configured
	if m.flixhq != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			flixRes, err := m.flixhq.GetTrending()
			if err == nil {
				mu.Lock()
				for _, it := range flixRes {
					if !seen[it.ID] {
						seen[it.ID] = true
						tmdbItems = append(tmdbItems, it)
					}
				}
				mu.Unlock()
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

	// Interleave or order: Show top TMDB catalog items first, followed by anime and demo
	var combined []MediaItem
	combined = append(combined, tmdbItems...)
	combined = append(combined, animeItems...)
	combined = append(combined, demoItems...)

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
		ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
		defer cancel()
		return m.animeEngine.GetStream(ctx, serverId)
	}
	if strings.HasPrefix(serverId, "demo-") {
		return m.demo.GetStream(serverId)
	}
	if strings.HasPrefix(serverId, "tmdb-") || strings.HasPrefix(serverId, "movie-") || strings.Contains(serverId, "-srv-") || strings.HasPrefix(serverId, "archive-") || title != "" || !strings.Contains(serverId, "flix") {
		ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
		defer cancel()

		stream, err := m.videoEngine.GetStream(ctx, serverId, title)
		if err == nil && stream != nil && len(stream.Sources) > 0 {
			if len(stream.Subtitles) == 0 {
				subs, _ := m.subtitleEngine.GetSubtitles(ctx, serverId, title)
				stream.Subtitles = subs
			}
			return stream, nil
		}

		// Fallback to anime engine if this might be an anime title or series
		if m.animeEngine != nil && title != "" {
			animeItems, aErr := m.animeEngine.Search(ctx, title)
			if aErr == nil && len(animeItems) > 0 {
				eps, epErr := m.animeEngine.GetEpisodes(ctx, animeItems[0].ID)
				if epErr == nil && len(eps) > 0 {
					targetEpIdx := 0
					reEpNum := regexp.MustCompile(`(?i)[eE][pP]?[-_]?(\d+)`)
					if matches := reEpNum.FindStringSubmatch(serverId); len(matches) > 1 {
						if n, err := strconv.Atoi(matches[1]); err == nil && n >= 1 && n <= len(eps) {
							targetEpIdx = n - 1
						}
					}
					targetEp := eps[targetEpIdx]
					servers, sErr := m.animeEngine.GetServers(ctx, targetEp.ID)
					if sErr == nil && len(servers) > 0 {
						animeStream, stErr := m.animeEngine.GetStream(ctx, servers[0].ID)
						if stErr == nil && animeStream != nil && len(animeStream.Sources) > 0 {
							return animeStream, nil
						}
					}
				}
			}
		}
	}
	stream, err := m.flixhq.GetStream(serverId)
	if err == nil && stream != nil && len(stream.Sources) > 0 {
		return stream, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	return m.videoEngine.GetStream(ctx, serverId, title)
}
