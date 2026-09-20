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
				ID:       "demo-sintel",
				Title:    "Sintel (4K Open Movie)",
				Type:     MediaTypeMovie,
				Poster:   "https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=500&q=80",
				Year:     "2010",
				Rating:   "8.8",
				Quality:  "4K HDR",
				Duration: "15m",
				Overview: "A lonely young woman, Sintel, helps and befriends a dragon, whom she names Scales. But when he is kidnapped by an adult dragon, Sintel embarks on a dangerous quest across a harsh world to find him.",
			},
			{
				ID:       "demo-tears-of-steel",
				Title:    "Tears of Steel (Sci-Fi VFX)",
				Type:     MediaTypeMovie,
				Poster:   "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80",
				Year:     "2012",
				Rating:   "8.5",
				Quality:  "1080p",
				Duration: "12m",
				Overview: "Set in a dystopian future Amsterdam, a group of warriors and scientists try to stage a desperate memory re-enactment to save the world from destructive cyborg robots.",
			},
			{
				ID:       "demo-big-buck-bunny",
				Title:    "Big Buck Bunny",
				Type:     MediaTypeMovie,
				Poster:   "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80",
				Year:     "2008",
				Rating:   "8.1",
				Quality:  "1080p 60fps",
				Duration: "10m",
				Overview: "A large and lovable rabbit deals with bullying forest creatures in this classic Blender Foundation open animation.",
			},
			{
				ID:       "demo-cosmos-laundromat",
				Title:    "Cosmos Laundromat",
				Type:     MediaTypeMovie,
				Poster:   "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80",
				Year:     "2015",
				Rating:   "8.7",
				Quality:  "4K",
				Duration: "12m",
				Overview: "On a desolate island, a suicidal sheep named Franck meets a mysterious salesman who offers him the adventure of a lifetime.",
			},
		},
	}
}

func (d *DemoProvider) Search(query string) ([]MediaItem, error) {
	q := strings.ToLower(query)
	var out []MediaItem
	for _, itm := range d.items {
		if strings.Contains(strings.ToLower(itm.Title), q) || strings.Contains(strings.ToLower(itm.Overview), q) {
			out = append(out, itm)
		}
	}
	return out, nil
}

func (d *DemoProvider) GetTrending() ([]MediaItem, error) {
	return d.items, nil
}

func (d *DemoProvider) GetDetails(id string) (*MediaDetails, error) {
	for _, itm := range d.items {
		if itm.ID == id {
			return &MediaDetails{
				MediaItem: itm,
				Genres:    []string{"Animation", "Sci-Fi", "Action", "Adventure"},
				Cast:      []string{"Blender Open Project", "Community Creators"},
				Seasons:   []int{1},
				TotalEpisodes: 1,
			}, nil
		}
	}
	return nil, fmt.Errorf("demo media not found: %s", id)
}

func (d *DemoProvider) GetEpisodes(id string, season int) ([]Episode, error) {
	return []Episode{
		{
			ID:     id + "-ep1",
			Number: 1,
			Season: 1,
			Title:  "Full Feature Presentation",
		},
	}, nil
}

func (d *DemoProvider) GetServers(episodeId string) ([]Server, error) {
	return []Server{
		{
			ID:   episodeId + "-srv-cdn1",
			Name: "FastCDN Master (HLS)",
		},
		{
			ID:   episodeId + "-srv-cdn2",
			Name: "Akamai Stream Mirror",
		},
	}, nil
}

func (d *DemoProvider) GetStream(serverId string) (*StreamResult, error) {
	var m3u8URL string
	var subs []Subtitle

	if strings.Contains(serverId, "tears-of-steel") {
		m3u8URL = "https://test-streams.mux.dev/tos_full/master.m3u8"
		subs = []Subtitle{
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_en.vtt", Lang: "English"},
		}
	} else if strings.Contains(serverId, "sintel") {
		m3u8URL = "https://bitmovin-a.akamaihd.net/content/sintel/hls/playlist.m3u8"
		subs = []Subtitle{
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_en.vtt", Lang: "English"},
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_de.vtt", Lang: "German"},
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_es.vtt", Lang: "Spanish"},
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_fr.vtt", Lang: "French"},
		}
	} else {
		// Big Buck Bunny and other defaults
		m3u8URL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
		subs = []Subtitle{
			{URL: "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_en.vtt", Lang: "English"},
		}
	}

	return &StreamResult{
		Sources: []Source{
			{
				URL:     m3u8URL,
				Quality: "Auto (Adaptive Bitrate)",
				IsM3U8:  true,
			},
		},
		Subtitles: subs,
		Headers: map[string]string{
			"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Watch2Gether/1.0",
		},
	}, nil
}
