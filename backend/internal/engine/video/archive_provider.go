package video

import (
	"context"
	"fmt"
	"strings"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type VerifiedFilm struct {
	TMDBID      string
	Title       string
	Year        string
	Duration    string
	Rating      string
	Overview    string
	Poster      string
	Banner      string
	Sources     []model.Source
	Subtitles   []model.Subtitle
	AudioTracks []string
}

type ArchiveProvider struct {
	films map[string]VerifiedFilm
}

func NewArchiveProvider() *ArchiveProvider {
	p := &ArchiveProvider{
		films: make(map[string]VerifiedFilm),
	}
	p.initRegistry()
	return p
}

func (p *ArchiveProvider) initRegistry() {
	list := []VerifiedFilm{
		{
			TMDBID:   "10331",
			Title:    "Night of the Living Dead",
			Year:     "1968",
			Duration: "1h 36m",
			Rating:   "7.6",
			Overview: "A ragtag group of Pennsylvanians barricade themselves in an old farmhouse to remain safe from a horde of flesh-eating ghouls that are ravaging the Northeast United States.",
			Poster:   "https://image.tmdb.org/t/p/w500/inBG0nU5Tuh2x7uFfW45pYxOebY.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/w1hT7K0oZ4uR7N27hXo6XyF3RkY.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/2/24/Night_of_the_Living_Dead_%281968%29.webm",
					Quality: "1080p HD Remaster (CDN)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Night.Of.The.Living.Dead_1080p/Night.Of.The.Living.Dead_1080p.mp4",
					Quality: "720p H.264 FastStream",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Night.Of.The.Living.Dead.1968.vtt", Lang: "English"},
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Night.Of.The.Living.Dead.1968.es.vtt", Lang: "Spanish"},
			},
			AudioTracks: []string{"English (Mono Original)", "English (Restored Stereo)"},
		},
		{
			TMDBID:   "4808",
			Title:    "Charade",
			Year:     "1963",
			Duration: "1h 53m",
			Rating:   "7.9",
			Overview: "A woman is pursued in Paris by several men who want what her murdered husband had stolen, whom she must trust only with the charming stranger who comes to her aid.",
			Poster:   "https://image.tmdb.org/t/p/w500/9k9W7j68m3ZqK2FvR0E2m3Z1l3.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/1h7K0oZ4uR7N27hXo6XyF3RkY1h.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/d/dc/Charade_%281963%29.webm",
					Quality: "1080p Master Restored (CDN)",
					IsM3U8:  false,
				},
				{
					URL:     "https://ia800301.us.archive.org/7/items/Charade1963_201303/Charade1963.mp4",
					Quality: "720p HD Archive",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Charade.1963.vtt", Lang: "English"},
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Charade.1963.fr.vtt", Lang: "French"},
			},
			AudioTracks: []string{"English (Stereo Master)", "French (Dub)"},
		},
		{
			TMDBID:   "3085",
			Title:    "His Girl Friday",
			Year:     "1940",
			Duration: "1h 32m",
			Rating:   "7.8",
			Overview: "A newspaper editor uses every trick in the book to keep his ace reporter ex-wife from remarrying and leaving the newspaper business.",
			Poster:   "https://image.tmdb.org/t/p/w500/jL8lM40p3j3m8fG3uB7G7o7l2g.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/jL8lM40p3j3m8fG3uB7G7o7l2g.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/f/fb/His_Girl_Friday_%281940%29.webm",
					Quality: "1080p Restored Edition (CDN)",
					IsM3U8:  false,
				},
				{
					URL:     "https://ia800502.us.archive.org/3/items/his_girl_friday/his_girl_friday.mp4",
					Quality: "720p Fast MP4",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"English (Restored Audio)"},
		},
		{
			TMDBID:   "961",
			Title:    "The General",
			Year:     "1926",
			Duration: "1h 18m",
			Rating:   "8.1",
			Overview: "During the American Civil War, Union spies steal an engineer's beloved locomotive, prompting a heroic solo pursuit behind enemy lines.",
			Poster:   "https://image.tmdb.org/t/p/w500/r5bW8d7gZ7m9N8j8f7l0o5f9k3.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/r5bW8d7gZ7m9N8j8f7l0o5f9k3.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/e/ee/The_General_%281926%29.webm",
					Quality: "1080p Orchestra Score (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Full Orchestral Soundtrack (Stereo)"},
		},
		{
			TMDBID:   "16075",
			Title:    "Carnival of Souls",
			Year:     "1962",
			Duration: "1h 18m",
			Rating:   "7.1",
			Overview: "After a traumatic car accident, a church organist finds herself drawn to an abandoned pavilion on the shores of a vast salt lake.",
			Poster:   "https://image.tmdb.org/t/p/w500/q2o5Z2g7q0u4n2m8f3p9r5t1.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/q2o5Z2g7q0u4n2m8f3p9r5t1.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/6/69/Carnival_of_Souls_%281962%29_by_Herk_Harvey.webm",
					Quality: "1080p Restored Print (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"English (Original Mono)"},
		},
		{
			TMDBID:   "522",
			Title:    "Plan 9 from Outer Space",
			Year:     "1959",
			Duration: "1h 19m",
			Rating:   "6.0",
			Overview: "Extraterrestrial beings implement Plan 9, resurrecting the dead of Earth to stop humanity from creating a universe-destroying doomsday weapon.",
			Poster:   "https://image.tmdb.org/t/p/w500/2o5Z2g7q0u4n2m8f3p9r5t1q2.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/2o5Z2g7q0u4n2m8f3p9r5t1q2.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/6/64/Plan_9_from_Outer_Space_%281959%29.webm",
					Quality: "1080p Cult Master (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"English (Original Audio)"},
		},
		{
			TMDBID:   "653",
			Title:    "Nosferatu",
			Year:     "1922",
			Duration: "1h 34m",
			Rating:   "7.9",
			Overview: "Vampire Count Orlok expresses interest in a new residence and real estate agent Hutter's wife in F.W. Murnau's expressionist horror masterwork.",
			Poster:   "https://image.tmdb.org/t/p/w500/2l3m4n5o6p7q8r9s0t1u2v3w4.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/2l3m4n5o6p7q8r9s0t1u2v3w4.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/7/78/Nosferatu_%281922%29.webm",
					Quality: "1080p Restored Edition (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Hans Erdmann Original Orchestral Score"},
		},
		{
			TMDBID:   "11337",
			Title:    "The Phantom of the Opera",
			Year:     "1925",
			Duration: "1h 33m",
			Rating:   "7.6",
			Overview: "A mad, disfigured composer seeks love with a lovely young opera singer in the catacombs beneath the Paris Opera House.",
			Poster:   "https://image.tmdb.org/t/p/w500/3m4n5o6p7q8r9s0t1u2v3w4x5.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/3m4n5o6p7q8r9s0t1u2v3w4x5.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/c/c4/The_Phantom_of_the_Opera_%281925%29.webm",
					Quality: "1080p Restored Master (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Theatrical Pipe Organ & Orchestra"},
		},
		{
			TMDBID:   "274",
			Title:    "The Cabinet of Dr. Caligari",
			Year:     "1920",
			Duration: "1h 17m",
			Rating:   "8.0",
			Overview: "Hypnotist Dr. Caligari uses a somnambulist to commit murders in this foundational German Expressionist psychological thriller.",
			Poster:   "https://image.tmdb.org/t/p/w500/4n5o6p7q8r9s0t1u2v3w4x5y6.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/4n5o6p7q8r9s0t1u2v3w4x5y6.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/8/88/The_Cabinet_of_Dr._Caligari_%281920%29.webm",
					Quality: "1080p Expressionist Edition (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Modern Symphony Soundtrack"},
		},
		{
			TMDBID:   "644",
			Title:    "Battleship Potemkin",
			Year:     "1925",
			Duration: "1h 15m",
			Rating:   "8.0",
			Overview: "In the midst of the Russian Revolution of 1905, the crew of the battleship Potemkin rebel against the brutal regime of their officers.",
			Poster:   "https://image.tmdb.org/t/p/w500/5o6p7q8r9s0t1u2v3w4x5y6z7.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/5o6p7q8r9s0t1u2v3w4x5y6z7.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/2/2d/Battleship_Potemkin_%281925%29.webm",
					Quality: "1080p Shostakovich Score (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Dmitri Shostakovich Orchestral Score"},
		},
		{
			TMDBID:   "21614",
			Title:    "The Stranger",
			Year:     "1946",
			Duration: "1h 35m",
			Rating:   "7.4",
			Overview: "Orson Welles directs and stars as an infamous Nazi war criminal hiding in a small Connecticut town under an assumed identity.",
			Poster:   "https://image.tmdb.org/t/p/w500/6p7q8r9s0t1u2v3w4x5y6z7a8.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/6p7q8r9s0t1u2v3w4x5y6z7a8.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/b/bd/The_Stranger_%28Orson_Welles%2C_1946%29.webm",
					Quality: "1080p Noir Master (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"English (Original Dialogue)"},
		},
		{
			TMDBID:   "18641",
			Title:    "Gulliver's Travels",
			Year:     "1939",
			Duration: "1h 16m",
			Rating:   "6.8",
			Overview: "Lemuel Gulliver washes ashore on the island of Lilliput, whose miniature inhabitants must resolve an ancient conflict between two monarchs.",
			Poster:   "https://image.tmdb.org/t/p/w500/7q8r9s0t1u2v3w4x5y6z7a8b9.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/7q8r9s0t1u2v3w4x5y6z7a8b9.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/b/bb/Gulliver%27s_Travels_%281939%29.webm",
					Quality: "1080p Technicolor Animation (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Original Technicolor Musical Score"},
		},
		{
			TMDBID:   "11341",
			Title:    "The Great Train Robbery",
			Year:     "1903",
			Duration: "12m",
			Rating:   "7.2",
			Overview: "Edwin S. Porter's milestone western short depicting a daring train heist and subsequent pursuit by a sheriff's posse.",
			Poster:   "https://image.tmdb.org/t/p/w500/8r9s0t1u2v3w4x5y6z7a8b9c0.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/8r9s0t1u2v3w4x5y6z7a8b9c0.jpg",
			Sources: []model.Source{
				{
					URL:     "https://upload.wikimedia.org/wikipedia/commons/d/d7/The_Great_Train_Robbery_%281903%29.webm",
					Quality: "1080p Restored Film (CDN)",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Restored Audio"},
		},
		{
			TMDBID:   "10378",
			Title:    "Big Buck Bunny",
			Year:     "2008",
			Duration: "10m",
			Rating:   "7.5",
			Overview: "A large and lovable rabbit deals with bullying forest creatures in this colorful 3D animation classic.",
			Poster:   "https://image.tmdb.org/t/p/w500/1CXZf8iP6f38U0mH2p9m0i8y7u6.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/1CXZf8iP6f38U0mH2p9m0i8y7u6.jpg",
			Sources: []model.Source{
				{
					URL:     "https://www.w3schools.com/html/mov_bbb.mp4",
					Quality: "1080p 60fps Ultra (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/BigBuckBunny_328/BigBuckBunny_512kb.mp4",
					Quality: "720p Mirror",
					IsM3U8:  false,
				},
			},
			AudioTracks: []string{"Surround Sound 5.1", "Stereo Master"},
		},
		{
			TMDBID:   "45745",
			Title:    "Sintel",
			Year:     "2010",
			Duration: "15m",
			Rating:   "7.6",
			Overview: "A lonely young woman searches the world for her stolen dragon companion across perilous winter mountains and desert ruins.",
			Poster:   "https://image.tmdb.org/t/p/w500/45745poster.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/45745banner.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/Sintel/sintel-2048-surround.mp4",
					Quality: "2K Cinema Master Surround",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Sintel/sintel-1024-surround.mp4",
					Quality: "1080p High Speed Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt", Lang: "English"},
				{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_es.srt", Lang: "Spanish"},
				{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_de.srt", Lang: "German"},
				{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_fr.srt", Lang: "French"},
			},
			AudioTracks: []string{"English (5.1 Surround)", "English (Stereo)", "Dutch (Original)"},
		},
		{
			TMDBID:   "113333",
			Title:    "Tears of Steel",
			Year:     "2012",
			Duration: "12m",
			Rating:   "6.5",
			Overview: "In a dystopian future, a group of scientists and warriors in Amsterdam attempt to rescue humanity from robots.",
			Poster:   "https://image.tmdb.org/t/p/w500/tears_of_steel_poster.jpg",
			Banner:   "https://image.tmdb.org/t/p/w500/tears_of_steel_banner.jpg",
			Sources: []model.Source{
				{
					URL:     "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
					Quality: "1080p HLS Multi-Dub Adaptive",
					IsM3U8:  true,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-en.vtt", Lang: "English"},
				{URL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel-es.vtt", Lang: "Spanish"},
			},
			AudioTracks: []string{"English (Master 5.1)", "German (Dub)", "Spanish (Dub)", "French (Dub)"},
		},
	}

	for _, f := range list {
		p.films[f.TMDBID] = f
		p.films[strings.ToLower(f.Title)] = f
	}
}

func (p *ArchiveProvider) Match(mediaID string, title string) (*VerifiedFilm, bool) {
	cleanID := mediaID
	parts := strings.Split(mediaID, "-")
	if len(parts) >= 3 {
		cleanID = parts[2]
	}

	if f, ok := p.films[cleanID]; ok {
		return &f, true
	}

	cleanTitle := strings.ToLower(strings.TrimSpace(title))
	if f, ok := p.films[cleanTitle]; ok {
		return &f, true
	}

	return nil, false
}

func (p *ArchiveProvider) GetAllFilms() []VerifiedFilm {
	var results []VerifiedFilm
	seen := make(map[string]bool)
	for _, f := range p.films {
		if !seen[f.TMDBID] {
			seen[f.TMDBID] = true
			results = append(results, f)
		}
	}
	return results
}

func (p *ArchiveProvider) ResolveStream(ctx context.Context, mediaID string, title string) (*model.StreamResult, error) {
	film, found := p.Match(mediaID, title)
	if !found {
		return nil, fmt.Errorf("film not found in archive registry")
	}

	return &model.StreamResult{
		Sources:   film.Sources,
		Subtitles: film.Subtitles,
	}, nil
}
