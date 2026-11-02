package video

import (
	"context"
	"fmt"
	"strings"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type VideoEngine struct {
	archiveProvider *ArchiveProvider
	featureProvider *TMDBFeatureProvider
	trackedSources  *TrackedSourceRegistry
}

func NewVideoEngine(tmdbKeys []string) *VideoEngine {
	return &VideoEngine{
		archiveProvider: NewArchiveProvider(),
		featureProvider: NewTMDBFeatureProvider(tmdbKeys),
		trackedSources:  NewTrackedSourceRegistry(),
	}
}

func (e *VideoEngine) GetArchiveProvider() *ArchiveProvider {
	return e.archiveProvider
}

func (e *VideoEngine) GetTrackedRegistry() *TrackedSourceRegistry {
	return e.trackedSources
}

// GetServers generates distinct, dynamically labeled servers for this specific media item
func (e *VideoEngine) GetServers(episodeID string, title string) ([]model.Server, error) {
	filmTitle := title
	if filmTitle == "" {
		filmTitle = "Feature"
	}

	return []model.Server{
		{
			ID:    fmt.Sprintf("%s-srv-yoru", episodeID),
			Name:  "Yoru",
			Flag:  "🇺🇸",
			Audio: "Original audio. May have 4K",
			Badge: "Primary",
		},
		{
			ID:    fmt.Sprintf("%s-srv-cypher", episodeID),
			Name:  "Cypher",
			Flag:  "🇺🇸",
			Audio: "Original audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-breach", episodeID),
			Name:  "Breach",
			Flag:  "🇺🇸",
			Audio: "Original audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-neon", episodeID),
			Name:  "Neon",
			Flag:  "🇺🇸",
			Audio: "Original audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-vyse", episodeID),
			Name:  "Vyse",
			Flag:  "🇺🇸",
			Audio: "Original audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-killjoy", episodeID),
			Name:  "Killjoy",
			Flag:  "🇩🇪",
			Audio: "German audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-fade", episodeID),
			Name:  "Fade",
			Flag:  "🇮🇳",
			Audio: "Hindi audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-omen", episodeID),
			Name:  "Omen",
			Flag:  "🇪🇸",
			Audio: "Spanish audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-raze", episodeID),
			Name:  "Raze",
			Flag:  "🇵🇹",
			Audio: "Portuguese audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-chamber", episodeID),
			Name:  "Chamber",
			Flag:  "🇫🇷",
			Audio: "French audio",
		},
		{
			ID:    fmt.Sprintf("%s-srv-jett", episodeID),
			Name:  "Jett",
			Flag:  "🇯🇵",
			Audio: "Japanese audio",
		},
	}, nil
}

// GetStream resolves the real stream sources and subtitles dynamically for this server/film
func (e *VideoEngine) GetStream(ctx context.Context, serverID string, title string) (*model.StreamResult, error) {
	// Extract media ID from serverID e.g. "tmdb-movie-10331-ep1-srv-1"
	mediaID := serverID
	if idx := strings.Index(serverID, "-srv-"); idx != -1 {
		mediaID = serverID[:idx]
	}
	if strings.Contains(mediaID, "-ep") {
		mediaID = strings.Split(mediaID, "-ep")[0]
	} else if strings.Contains(mediaID, "-s") {
		mediaID = strings.Split(mediaID, "-s")[0]
	}

	// 0. Check Tracked Pinned Sources (Guarantees zero regression on verified titles)
	if pinned, found := e.trackedSources.GetPinned(title, mediaID); found {
		sources := pinned.Sources
		if (strings.HasSuffix(serverID, "-srv-2") || strings.HasSuffix(serverID, "-srv-cypher")) && len(sources) > 1 {
			sources = []model.Source{sources[1], sources[0]}
		}
		res := &model.StreamResult{
			Sources:   sources,
			Subtitles: pinned.Subtitles,
			Headers:   pinned.Headers,
		}
		e.trackedSources.RecordResolution(title, mediaID, pinned.Provider, res)
		return res, nil
	}

	// 1. Try pre-indexed curated public domain / classic films
	if film, found := e.archiveProvider.Match(mediaID, title); found {
		sources := film.Sources
		if (strings.HasSuffix(serverID, "-srv-2") || strings.HasSuffix(serverID, "-srv-cypher")) && len(sources) > 1 {
			sources = []model.Source{sources[1], sources[0]}
		}
		res := &model.StreamResult{
			Sources:   sources,
			Subtitles: film.Subtitles,
		}
		e.trackedSources.RecordResolution(title, mediaID, "ArchiveProvider (Pre-indexed)", res)
		return res, nil
	}

	// 2. For modern/commercial films, resolve real multi-source feature streams FIRST (FlixHQ/Vidmoly/VidSrc)
	if title != "" {
		res, err := e.featureProvider.ResolveFeatureStream(ctx, mediaID, title)
		if err == nil && res != nil && len(res.Sources) > 0 {
			sources := res.Sources
			if strings.HasSuffix(serverID, "-srv-2") && len(sources) > 1 {
				sources = []model.Source{sources[1], sources[0]}
			}
			result := &model.StreamResult{
				Sources:   sources,
				Subtitles: res.Subtitles,
				Headers:   res.Headers,
			}
			e.trackedSources.RecordResolution(title, mediaID, "FlixHQ Feature Scraper", result)
			return result, nil
		}
	}

	// 3. Fallback to dynamic archive for classic, vintage, and catalog films
	if title != "" {
		film, err := e.archiveProvider.SearchDynamicArchive(ctx, mediaID, title, "")
		if err == nil && film != nil && len(film.Sources) > 0 {
			sources := film.Sources
			if strings.HasSuffix(serverID, "-srv-2") && len(sources) > 1 {
				sources = []model.Source{sources[1], sources[0]}
			}
			result := &model.StreamResult{
				Sources:   sources,
				Subtitles: film.Subtitles,
			}
			e.trackedSources.RecordResolution(title, mediaID, "ArchiveOrg Dynamic Fallback", result)
			return result, nil
		}
	}

	// 4. Return clean error - zero fake fallback videos
	return nil, fmt.Errorf("no verified video stream found for %q across any provider", title)
}
