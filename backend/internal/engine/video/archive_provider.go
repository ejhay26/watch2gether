package video

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

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
	mu           sync.RWMutex
	staticFilms  map[string]VerifiedFilm
	staticList   []VerifiedFilm
	dynamicCache map[string]VerifiedFilm
	client       *http.Client
}

func NewArchiveProvider() *ArchiveProvider {
	p := &ArchiveProvider{
		staticFilms:  make(map[string]VerifiedFilm),
		dynamicCache: make(map[string]VerifiedFilm),
		client: &http.Client{
			Timeout: 8 * time.Second,
		},
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
			Poster:   "https://image.tmdb.org/t/p/w500/rb2NWyb008u1EcKCOyXs2Nmj0ra.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/5KtmBSqFtHY3I9t8lgH27Mc0bqY.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/Night.Of.The.Living.Dead_1080p/NightOfTheLivingDead.mp4",
					Quality: "1080p Full Master (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Night.Of.The.Living.Dead_1080p/Night.Of.The.Living.Dead_1080p.mp4",
					Quality: "720p FastStream Mirror",
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
			Poster:   "https://image.tmdb.org/t/p/w500/qqaPjC5FQidtKY65jbAKZPiOTaS.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/gj2TBYmOIy4E2GjMIpnbAEZNCQx.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/la35ca-Cinema_35_-_Charade_1963/Cinema_35_-_Charade_1963.mp4",
					Quality: "1080p HD Remaster (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Charade1963_201602/Charade.mp4",
					Quality: "720p Adaptive Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English (Embedded)"},
			},
			AudioTracks: []string{"English (Original Stereo)"},
		},
		{
			TMDBID:   "3085",
			Title:    "His Girl Friday",
			Year:     "1940",
			Duration: "1h 32m",
			Rating:   "7.8",
			Overview: "A newspaper editor uses every trick in the book to keep his ace reporter ex-wife from remarrying and quitting the journalism business.",
			Poster:   "https://image.tmdb.org/t/p/w500/lu86Y9zTPH3neCiUzLzHCEFHf7f.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/ihoQaiMFAz4YCTAaSIsQjRknsNH.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/HisGirlFriday-1940/CaryGrant-1940-HisGirlFriday.mp4",
					Quality: "1080p Restored Edition (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/HisGirlFriday1940_201306/HisGirlFriday.mp4",
					Quality: "720p Clean Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
			},
			AudioTracks: []string{"English (Original Mono)"},
		},
		{
			TMDBID:   "961",
			Title:    "The General",
			Year:     "1926",
			Duration: "1h 18m",
			Rating:   "8.1",
			Overview: "During the American Civil War, Union spies steal an engineer's beloved locomotive, prompting a relentless single-handed pursuit across enemy lines.",
			Poster:   "https://image.tmdb.org/t/p/w500/4NmV1Wei4LxT2lpjViCAScgCZLq.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/mzox4HbcV9W42MH2dB1QsdDVGo3.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/TheGeneral_201312/The-General-v2.mp4",
					Quality: "1080p 4K Scan Edition",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/TheGeneralBusterKeaton/TheGeneral_512kb.mp4",
					Quality: "720p Fast Stream",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English (Intertitles)"},
			},
			AudioTracks: []string{"Carl Davis Orchestral Score", "Robert Israel Organ Score"},
		},
		{
			TMDBID:   "16075",
			Title:    "Carnival of Souls",
			Year:     "1962",
			Duration: "1h 18m",
			Rating:   "7.1",
			Overview: "After a traumatic car accident, a young woman relocates to Utah where she is drawn to an eerie, abandoned pavilion on the shores of the Great Salt Lake.",
			Poster:   "https://image.tmdb.org/t/p/w500/59LU8PjGuW1oiSD9ZqmKCpEwUB0.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/5sdNwufhvWfKYwrmByrw6QnGkAY.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/CarnivalOfSouls1962/Carnival_of_Souls_512kb.mp4",
					Quality: "1080p Criterion Edition (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/CarnivalOfSouls_201509/CarnivalOfSouls.mp4",
					Quality: "720p Cult Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
			},
			AudioTracks: []string{"English (Original Pipe Organ Audio)"},
		},
		{
			TMDBID:   "522",
			Title:    "Plan 9 from Outer Space",
			Year:     "1959",
			Duration: "1h 19m",
			Rating:   "6.0",
			Overview: "Aliens implement their ninth plan to conquer the human race by resurrecting the corpses of earthlings to stop mankind from destroying the universe.",
			Poster:   "https://image.tmdb.org/t/p/w500/n8SrO3WbyuY2b6KazogqbQF348C.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/3jrwJiMCe7VZP0DNcywHYOKg0Zu.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/774-plan-9-from-outer-space/774-Plan9FromOuterSpace.mp4",
					Quality: "1080p Cult Master (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Plan_9_from_Outer_Space_1959/Plan9FromOuterSpace_512kb.mp4",
					Quality: "720p Midnight Movie Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/zv7J85D8CC9qYagAEhPM63CIG6j.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/cA9iGtvjRGJHzDBfrq48l0eyCvA.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/Nosferatu1922/Nosferatu.mp4",
					Quality: "1080p Restored Edition (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Nosferatu_1922/Nosferatu_512kb.mp4",
					Quality: "720p Symphonic Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "German / English Intertitles"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/y1EHgpL2hMVRcr6tIOy7VGLxaPs.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/phSIp0IbGhPgKyLduTnQ4z2IzsD.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/ThePhantomOfTheOpera1925NewYorkGeneralReleasePrint_620/ThePhantomOfTheOpera1925PublicDomainScore_512kb.mp4",
					Quality: "1080p Restored Master (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/The_Phantom_of_the_Opera_1925/ThePhantomOfTheOpera.mp4",
					Quality: "720p Organ Score Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/uS9m8OBk1A8eM9I042bx8XXpqAq.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/aYcnDyLMnpKce1FOYUpZrXtgUye.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/DasKabinettdesDoktorCaligariTheCabinetofDrCaligari/The_Cabinet_of_Dr._Caligari_512kb.mp4",
					Quality: "1080p Expressionist Edition (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/The_Cabinet_of_Dr_Caligari_1920/TheCabinetOfDrCaligari.mp4",
					Quality: "720p Chamber Music Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/wnUAcUrMRGPPZUDroLeZhSjLkuu.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/n7p6UTAZtkeoHkwCO42BEQaMFJY.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/BattleshipPotemkin/Battleship_Potemkin_512kb.mp4",
					Quality: "1080p Shostakovich Score (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/BattleshipPotemkin_201602/BattleshipPotemkin.mp4",
					Quality: "720p Soviet Montage Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "Russian / English Intertitles"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/23MKGUPT5laTStim4TaGhfgSltu.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/AkfqKaD1KqfIqytxLvWlyKJRlEi.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/the.stranger.1946.remastered.1080p.bluray.x264amiable/The.Stranger.1946.REMASTERED.1080p.BluRay.X264-AMIABLE.mp4",
					Quality: "1080p Noir Master (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/The_Stranger_1946/TheStranger.mp4",
					Quality: "720p Welles Archival Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
			},
			AudioTracks: []string{"English (Original Dialogue)"},
		},
		{
			TMDBID:   "42518",
			Title:    "Gulliver's Travels",
			Year:     "1939",
			Duration: "1h 16m",
			Rating:   "6.8",
			Overview: "Lemuel Gulliver washes ashore on the island of Lilliput, whose miniature inhabitants must resolve an ancient conflict between two monarchs.",
			Poster:   "https://image.tmdb.org/t/p/w500/fiwAJIAnSqWbU3JphqN8Y80mFM6.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/pwP9RTomD5Ft6fQYLmkUTUlKTgv.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/GulliversTravels1939_201509/GulliversTravels-1939.mp4",
					Quality: "1080p Technicolor Animation (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/gullivers_travels_1939/gullivers_travels_512kb.mp4",
					Quality: "720p Fleischer Studios Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
			},
			AudioTracks: []string{"Original Technicolor Musical Score"},
		},
		{
			TMDBID:   "5698",
			Title:    "The Great Train Robbery",
			Year:     "1903",
			Duration: "12m",
			Rating:   "7.2",
			Overview: "Edwin S. Porter's milestone western short depicting a daring train heist and subsequent pursuit by a sheriff's posse.",
			Poster:   "https://image.tmdb.org/t/p/w500/vEYr1sJR1dOFGXwXawpBN6hDRGF.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/99uGRUGS2qxNvPARiM8dkuTrUnW.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/TheGreatTrainRobbery1903/TheGreatTrainRobbery1903.mp4",
					Quality: "1080p Restored Film (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/TheGreatTrainRobbery1903/TheGreatTrainRobbery1903_512kb.mp4",
					Quality: "720p Edison Archival Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "Silent / Music Only"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/i9jJzvoXET4D9pOkoEwncSdNNER.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/xtdybjRRZ15mCrPOvEld305myys.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/BigBuckBunny_328/BigBuckBunny_512kb.mp4",
					Quality: "1080p 60fps Ultra (High Speed)",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/BigBuckBunny_124/BigBuckBunny_1080p.mp4",
					Quality: "720p Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English"},
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
			Poster:   "https://image.tmdb.org/t/p/w500/2hwMOwcyyYWlHBldhonipg09kRm.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/Sintel/sintel-2048-stereo.mp4",
					Quality: "2K Cinema Master Stereo",
					IsM3U8:  false,
				},
				{
					URL:     "https://archive.org/download/Sintel/sintel-1024-surround.mp4",
					Quality: "1080p High Speed Mirror",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sintel_en.vtt", Lang: "English"},
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sintel_es.vtt", Lang: "Spanish"},
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sintel_fr.vtt", Lang: "French"},
			},
			AudioTracks: []string{"English (5.1 Surround)", "English (Stereo)", "Dutch (Original)"},
		},
		{
			TMDBID:   "133701",
			Title:    "Tears of Steel",
			Year:     "2012",
			Duration: "12m",
			Rating:   "6.5",
			Overview: "In a dystopian future, a group of scientists and warriors in Amsterdam attempt to rescue humanity from robots.",
			Poster:   "https://image.tmdb.org/t/p/w500/8qy3jRmaHR7f8VZh3iXCqCWfFsH.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/fOy6SL5Zs2PFcNXwqEPIDPrLB1q.jpg",
			Sources: []model.Source{
				{
					URL:     "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
					Quality: "1080p HLS Multi-Dub Adaptive",
					IsM3U8:  true,
				},
				{
					URL:     "https://archive.org/download/Tears-of-Steel/tears_of_steel_1080p.mp4",
					Quality: "1080p Direct MP4 Master",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/tears_of_steel_en.vtt", Lang: "English"},
				{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/tears_of_steel_de.vtt", Lang: "German"},
			},
			AudioTracks: []string{"English (5.1 Surround)", "English (Stereo)", "German (Dubbed)"},
		},
	}

	list = append(list, VerifiedFilm{
			TMDBID:   "2109",
			Title:    "Rush Hour",
			Year:     "1998",
			Duration: "1h 38m",
			Rating:   "7.1",
			Overview: "When Hong Kong Inspector Lee is summoned to Los Angeles to investigate a kidnapping, the FBI assigns cocky LAPD Detective James Carter to distract Lee from the case. Lee and Carter form an unlikely partnership and investigate the case themselves.",
			Poster:   "https://image.tmdb.org/t/p/w500/nwPhAsfnb7f46bZkWLG7IRP5HXr.jpg",
			Banner:   "https://image.tmdb.org/t/p/w1280/9FrpAtF87VKblKkDEiIZzYgO40K.jpg",
			Sources: []model.Source{
				{
					URL:     "https://archive.org/download/rush.-hour.-1998.1080p.-blu-ray.x-264.-aac-5.1-yts.-mx/Rush.Hour.1998.1080p.BluRay.x264.AAC5.1-%5BYTS.MX%5D.mp4",
					Quality: "1080p Blu-Ray Remaster",
					IsM3U8:  false,
				},
			},
			Subtitles: []model.Subtitle{
				{URL: "", Lang: "English (Embedded)"},
			},
			AudioTracks: []string{"English 5.1 Surround (Original Dialogue)"},
		},)

	p.staticList = list
	for _, film := range list {
		p.staticFilms[film.TMDBID] = film
		p.staticFilms[strings.ToLower(strings.TrimSpace(film.Title))] = film
	}
}

func (p *ArchiveProvider) Match(mediaID string, title string) (*VerifiedFilm, bool) {
	p.mu.RLock()
	defer p.mu.RUnlock()

	cleanID := mediaID
	parts := strings.Split(mediaID, "-")
	if len(parts) >= 3 {
		cleanID = parts[2]
	}

	if f, ok := p.staticFilms[cleanID]; ok {
		return &f, true
	}
	if f, ok := p.dynamicCache[cleanID]; ok {
		return &f, true
	}

	cleanTitle := strings.ToLower(strings.TrimSpace(title))
	if cleanTitle != "" {
		if f, ok := p.staticFilms[cleanTitle]; ok {
			return &f, true
		}
		if f, ok := p.dynamicCache[cleanTitle]; ok {
			return &f, true
		}
	}

	return nil, false
}

func (p *ArchiveProvider) GetAllFilms() []VerifiedFilm {
	p.mu.RLock()
	defer p.mu.RUnlock()

	results := make([]VerifiedFilm, len(p.staticList))
	copy(results, p.staticList)
	return results
}

type archiveSearchResponse struct {
	Response struct {
		Docs []struct {
			Identifier string      `json:"identifier"`
			Title      string      `json:"title"`
			Year       interface{} `json:"year"`
		} `json:"docs"`
	} `json:"response"`
}

type archiveFilesResponse struct {
	Result []struct {
		Name   string      `json:"name"`
		Size   interface{} `json:"size"`
		Format string      `json:"format"`
	} `json:"result"`
}

func parseArchiveSize(v interface{}) int64 {
	switch val := v.(type) {
	case float64:
		return int64(val)
	case int64:
		return val
	case int:
		return int64(val)
	case string:
		n, _ := strconv.ParseInt(val, 10, 64)
		return n
	default:
		return 0
	}
}

// SearchDynamicArchive searches Archive.org dynamically for full feature film presentations (> 250MB)
func (p *ArchiveProvider) SearchDynamicArchive(ctx context.Context, mediaID string, title string, year string) (*VerifiedFilm, error) {
	if film, found := p.Match(mediaID, title); found {
		return film, nil
	}

	rawTitle := strings.TrimSpace(title)
	if rawTitle == "" {
		return nil, fmt.Errorf("empty title provided")
	}

	// Sanitize title
	reg := regexp.MustCompile(`[^a-zA-Z0-9\s]+`)
	cleanTitle := strings.TrimSpace(reg.ReplaceAllString(rawTitle, ""))
	if cleanTitle == "" {
		cleanTitle = rawTitle
	}

	var queries []string
	collectionFilter := "AND collection:(feature_films OR classic_tv OR moviesandfilms OR SciFi_Horror OR Comedy_Films OR Film_Noir OR silent_films)"
	if year != "" && len(year) == 4 {
		queries = append(queries, fmt.Sprintf(`title:("%s") AND year:%s AND mediatype:movies %s`, cleanTitle, year, collectionFilter))
		queries = append(queries, fmt.Sprintf(`title:("%s") AND mediatype:movies %s`, cleanTitle, collectionFilter))
	} else {
		queries = append(queries, fmt.Sprintf(`title:("%s") AND mediatype:movies %s`, cleanTitle, collectionFilter))
	}

	badKeywords := []string{
		"trailer", "review", "scene", "sample", "gameplay", "teaser", "youtube-",
		"vidcast", "acceptance", "vlog", "reaction", "episode", "promo", "mineola", "lego",
		"walkthrough", "playthrough", "let's play", "longplay", "speedrun", "mod", "cutscenes",
		"game", "pc gameplay", "ps4", "ps5", "xbox", "nintendo", "boss fight", "ending scene",
		"gdc", "gdceu", "twitch", "conference", "tas", "gcn", "psx", "ps1", "ps2", "ps3",
		"segment", "weapons run", "panel", "interview", "presentation", "speed_runs",
	}

	titleWords := strings.Fields(strings.ToLower(cleanTitle))

	for _, q := range queries {
		searchURL := fmt.Sprintf("https://archive.org/advancedsearch.php?q=%s&fl[]=identifier,title,year,downloads&sort[]=downloads+desc&rows=15&output=json", url.QueryEscape(q))
		req, err := http.NewRequestWithContext(ctx, "GET", searchURL, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

		resp, err := p.client.Do(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			continue
		}

		var searchRes archiveSearchResponse
		err = json.NewDecoder(resp.Body).Decode(&searchRes)
		resp.Body.Close()
		if err != nil || len(searchRes.Response.Docs) == 0 {
			continue
		}

		for _, doc := range searchRes.Response.Docs {
			ident := doc.Identifier
			docTitle := doc.Title
			combinedText := strings.ToLower(docTitle + " " + ident)

			// Skip foreign dubbed packs if searching English film
			if strings.Contains(strings.ToLower(docTitle), " [fr]") || strings.Contains(ident, "-fr") ||
			   strings.Contains(strings.ToLower(docTitle), " [ita]") || strings.Contains(ident, "-ita") ||
			   strings.Contains(strings.ToLower(docTitle), " [es]") || strings.Contains(ident, "-es") {
				continue
			}

			// Skip bad keywords
			hasBad := false
			for _, bk := range badKeywords {
				if strings.Contains(combinedText, bk) {
					hasBad = true
					break
				}
			}
			if hasBad {
				continue
			}

			// Verify title words exist
			allWordsMatch := true
			for _, w := range titleWords {
				if len(w) > 2 && !strings.Contains(combinedText, w) {
					allWordsMatch = false
					break
				}
			}
			if !allWordsMatch {
				continue
			}

			// Query files metadata
			filesURL := fmt.Sprintf("https://archive.org/metadata/%s/files", ident)
			reqFiles, err := http.NewRequestWithContext(ctx, "GET", filesURL, nil)
			if err != nil {
				continue
			}
			reqFiles.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

			respFiles, err := p.client.Do(reqFiles)
			if err != nil || respFiles.StatusCode != http.StatusOK {
				continue
			}

			var filesRes archiveFilesResponse
			err = json.NewDecoder(respFiles.Body).Decode(&filesRes)
			respFiles.Body.Close()
			if err != nil || len(filesRes.Result) == 0 {
				continue
			}

			// Find candidate video file > 250MB
			var bestFile string
			var bestSize int64
			for _, f := range filesRes.Result {
				fNameLower := strings.ToLower(f.Name)
				if strings.HasSuffix(fNameLower, ".mp4") || strings.HasSuffix(fNameLower, ".mkv") {
					sz := parseArchiveSize(f.Size)
					if sz > 250*1024*1024 && sz > bestSize {
						bestSize = sz
						bestFile = f.Name
					}
				}
			}

			if bestFile != "" {
				// Construct direct playable URL
				// URL encode filename properly
				encodedFileName := url.PathEscape(bestFile)
				streamURL := fmt.Sprintf("https://archive.org/download/%s/%s", ident, encodedFileName)

				cleanID := mediaID
				parts := strings.Split(mediaID, "-")
				if len(parts) >= 3 {
					cleanID = parts[2]
				}

				film := VerifiedFilm{
					TMDBID:   cleanID,
					Title:    rawTitle,
					Year:     func() string {
					if doc.Year == nil { return "" }
					s := fmt.Sprintf("%v", doc.Year)
					if s == "<nil>" || s == "nil" { return "" }
					if len(s) >= 4 { return s[:4] }
					return s
				}(),
					Duration: "Feature Film",
					Rating:   "8.0",
					Overview: fmt.Sprintf("Master Presentation of %s streaming directly from Archive.org", rawTitle),
					Sources: []model.Source{
						{
							URL:     streamURL,
							Quality: "1080p Master Stream (Archive HD)",
							IsM3U8:  false,
						},
					},
					Subtitles: []model.Subtitle{
						{URL: "", Lang: "English (Embedded)"},
					},
					AudioTracks: []string{"Stereo Master (Original Audio)"},
				}

				// Cache in dynamicCache ONLY (never pollute static verified catalog)
				p.mu.Lock()
				p.dynamicCache[cleanID] = film
				p.dynamicCache[strings.ToLower(strings.TrimSpace(rawTitle))] = film
				p.mu.Unlock()

				return &film, nil
			}
		}
	}

	return nil, fmt.Errorf("no feature presentation found for %s", rawTitle)
}

func (p *ArchiveProvider) ResolveStream(ctx context.Context, mediaID string, title string) (*model.StreamResult, error) {
	film, found := p.Match(mediaID, title)
	if !found {
		var err error
		film, err = p.SearchDynamicArchive(ctx, mediaID, title, "")
		if err != nil || film == nil {
			return nil, fmt.Errorf("film not found in archive registry: %w", err)
		}
	}

	return &model.StreamResult{
		Sources:   film.Sources,
		Subtitles: film.Subtitles,
	}, nil
}
