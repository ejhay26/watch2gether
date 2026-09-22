package scraper

import (
	"fmt"
	"strings"
)

type DemoProvider struct {
	items []MediaItem
}

func NewDemoProvider() *DemoProvider {
	return &DemoProvider{
		items: []MediaItem{
			{
				ID:           "demo-tears-of-steel",
				Title:        "Tears of Steel (Sci-Fi VFX)",
				Type:         MediaTypeMovie,
				Poster:       "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80",
				Banner:       "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&q=80",
				Year:         "2012",
				Rating:       "8.5",
				RatingSource: "OpenFilm",
				Quality:      "1080p Full HD",
				Duration:     "0h 12m",
				Overview:     "Set in a dystopian future Amsterdam, a group of warriors and scientists try to stage a desperate memory re-enactment to save the world from destructive cyborg robots.",
			},
			{
				ID:           "demo-sintel",
				Title:        "Sintel (4K Fantasy)",
				Type:         MediaTypeMovie,
				Poster:       "https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=500&q=80",
				Banner:       "https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=1200&q=80",
				Year:         "2010",
				Rating:       "8.8",
				RatingSource: "OpenFilm",
				Quality:      "4K HDR",
				Duration:     "0h 15m",
				Overview:     "A lonely young woman, Sintel, helps and befriends a dragon, whom she names Scales. But when he is kidnapped by an adult dragon, Sintel embarks on a dangerous quest across a harsh world to find him.",
			},
			{
				ID:           "demo-big-buck-bunny",
				Title:        "Big Buck Bunny",
				Type:         MediaTypeMovie,
				Poster:       "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80",
				Banner:       "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&q=80",
				Year:         "2008",
				Rating:       "8.1",
				RatingSource: "OpenFilm",
				Quality:      "1080p 60fps",
				Duration:     "0h 10m",
				Overview:     "A large and lovable rabbit deals with bullying forest creatures in this classic Blender Foundation open animation.",
			},
			{
				ID:           "demo-elephants-dream",
				Title:        "Elephant's Dream",
				Type:         MediaTypeMovie,
				Poster:       "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80",
				Banner:       "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200&q=80",
				Year:         "2006",
				Rating:       "7.8",
				RatingSource: "OpenFilm",
				Quality:      "1080p",
				Duration:     "0h 11m",
				Overview:     "Two people explore the complex machine inside an extraordinary world. The very first open movie created with open-source 3D software.",
			},
		},
	}
}

func (p *DemoProvider) Search(query string) ([]MediaItem, error) {
	q := strings.ToLower(query)
	var results []MediaItem
	for _, item := range p.items {
		if strings.Contains(strings.ToLower(item.Title), q) || strings.Contains(strings.ToLower(item.Overview), q) {
			results = append(results, item)
		}
	}
	return results, nil
}

func (p *DemoProvider) GetTrending() ([]MediaItem, error) {
	return p.items, nil
}

func (p *DemoProvider) GetDetails(id string) (*MediaDetails, error) {
	for _, item := range p.items {
		if item.ID == id {
			return &MediaDetails{
				MediaItem: item,
				Genres:    []string{"Animation", "Short Film", "Sci-Fi", "Open Source"},
				Cast:      []string{"Blender Foundation", "Open Media Community"},
				Seasons:   []int{1},
			}, nil
		}
	}
	return nil, fmt.Errorf("demo media not found: %s", id)
}

func (p *DemoProvider) GetEpisodes(id string, season int) ([]Episode, error) {
	for _, item := range p.items {
		if item.ID == id {
			return []Episode{
				{
					ID:       fmt.Sprintf("%s-ep1", id),
					Number:   1,
					Season:   1,
					Title:    item.Title,
					Overview: item.Overview,
				},
			}, nil
		}
	}
	return nil, fmt.Errorf("demo media not found: %s", id)
}

func (p *DemoProvider) GetServers(episodeId string) ([]Server, error) {
	return []Server{
		{
			ID:   fmt.Sprintf("%s-srv-master", episodeId),
			Name: "AutoEmbed Master HLS (Multi-Audio)",
		},
		{
			ID:   fmt.Sprintf("%s-srv-akamai", episodeId),
			Name: "Akamai Ultra Fast CDN",
		},
		{
			ID:   fmt.Sprintf("%s-srv-direct", episodeId),
			Name: "Direct MP4 Archive Mirror",
		},
	}, nil
}

func (p *DemoProvider) GetStream(serverId string) (*StreamResult, error) {
	var sources []Source

	if strings.Contains(serverId, "demo-big-buck-bunny") {
		sources = []Source{
			{
				URL:     "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
				Quality: "Auto (1080p HLS Adaptive)",
				IsM3U8:  true,
			},
			{
				URL:     "https://archive.org/download/BigBuckBunny_328/BigBuckBunny_512kb.mp4",
				Quality: "Direct MP4 Mirror",
				IsM3U8:  false,
			},
		}
	} else if strings.Contains(serverId, "demo-sintel") {
		sources = []Source{
			{
				URL:     "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
				Quality: "Auto (1080p HLS Multi-Audio)",
				IsM3U8:  true,
			},
			{
				URL:     "https://archive.org/download/Sintel/sintel-2048-surround.mp4",
				Quality: "Direct MP4 Archive",
				IsM3U8:  false,
			},
		}
	} else if strings.Contains(serverId, "demo-elephants-dream") {
		sources = []Source{
			{
				URL:     "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
				Quality: "Auto (Apple HLS Multi-Dub)",
				IsM3U8:  true,
			},
			{
				URL:     "https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4",
				Quality: "Direct MP4 Mirror",
				IsM3U8:  false,
			},
		}
	} else {
		// Tears of steel default
		sources = []Source{
			{
				URL:     "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
				Quality: "Auto (1080p HLS Multi-Dub)",
				IsM3U8:  true,
			},
			{
				URL:     "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8",
				Quality: "Akamai CDN Mirror",
				IsM3U8:  true,
			},
			{
				URL:     "https://archive.org/download/Tears-of-Steel/tears_of_steel_720p.mp4",
				Quality: "Direct 720p MP4",
				IsM3U8:  false,
			},
		}
	}

	subtitles := []Subtitle{
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-en.vtt", Lang: "English"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-de.vtt", Lang: "German"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-fr.vtt", Lang: "French"},
		{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-es.vtt", Lang: "Spanish"},
	}

	return &StreamResult{
		Sources:   sources,
		Subtitles: subtitles,
		Headers: map[string]string{
			"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WatchHub/1.0",
		},
	}, nil
}
