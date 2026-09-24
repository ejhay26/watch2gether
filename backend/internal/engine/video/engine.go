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
}

func NewVideoEngine(tmdbKeys []string) *VideoEngine {
	return &VideoEngine{
		archiveProvider: NewArchiveProvider(),
		featureProvider: NewTMDBFeatureProvider(tmdbKeys),
	}
}

func (e *VideoEngine) GetArchiveProvider() *ArchiveProvider {
	return e.archiveProvider
}

// GetServers generates distinct, dynamically labeled servers for this specific media item
func (e *VideoEngine) GetServers(episodeID string, title string) ([]model.Server, error) {
	// Check if this media item matches a registered archive film
	mediaID := episodeID
	if strings.Contains(episodeID, "-ep") {
		mediaID = strings.Split(episodeID, "-ep")[0]
	} else if strings.Contains(episodeID, "-s") {
		mediaID = strings.Split(episodeID, "-s")[0]
	}

	film, found := e.archiveProvider.Match(mediaID, title)
	if found {
		var servers []model.Server
		for i, src := range film.Sources {
			servers = append(servers, model.Server{
				ID:   fmt.Sprintf("%s-srv-%d", episodeID, i+1),
				Name: fmt.Sprintf("%s (%s)", src.Quality, film.Title),
			})
		}
		if len(servers) == 0 {
			servers = append(servers, model.Server{
				ID:   fmt.Sprintf("%s-srv-master", episodeID),
				Name: fmt.Sprintf("Master Direct Stream (%s)", film.Title),
			})
		}
		return servers, nil
	}

	// Dynamic servers for modern/trending TMDB items
	filmTitle := title
	if filmTitle == "" {
		filmTitle = "Feature"
	}

	return []model.Server{
		{
			ID:   fmt.Sprintf("%s-srv-master", episodeID),
			Name: fmt.Sprintf("Ultra HD Master (%s)", filmTitle),
		},
		{
			ID:   fmt.Sprintf("%s-srv-cdn", episodeID),
			Name: fmt.Sprintf("FastCDN High-Speed Mirror (%s)", filmTitle),
		},
		{
			ID:   fmt.Sprintf("%s-srv-backup", episodeID),
			Name: fmt.Sprintf("Adaptive Direct Stream (%s)", filmTitle),
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

	// 1. Try pre-indexed curated public domain / classic films
	if film, found := e.archiveProvider.Match(mediaID, title); found {
		sources := film.Sources
		if strings.HasSuffix(serverID, "-srv-2") && len(sources) > 1 {
			sources = []model.Source{sources[1], sources[0]}
		}
		return &model.StreamResult{
			Sources:   sources,
			Subtitles: film.Subtitles,
		}, nil
	}

	// 2. For modern/commercial films, resolve real multi-source feature streams FIRST (FlixHQ/Vidmoly/VidSrc)
	if title != "" {
		res, err := e.featureProvider.ResolveFeatureStream(ctx, mediaID, title)
		if err == nil && res != nil && len(res.Sources) > 0 {
			sources := res.Sources
			if strings.HasSuffix(serverID, "-srv-2") && len(sources) > 1 {
				sources = []model.Source{sources[1], sources[0]}
			}
			return &model.StreamResult{
				Sources:   sources,
				Subtitles: res.Subtitles,
				Headers:   res.Headers,
			}, nil
		}
	}

	// 3. Try dynamic archive ONLY if explicit archive request or strictly verified feature film collection
	if title != "" && (strings.HasPrefix(serverID, "archive-") || strings.HasPrefix(mediaID, "archive-")) {
		film, err := e.archiveProvider.SearchDynamicArchive(ctx, mediaID, title, "")
		if err == nil && film != nil && len(film.Sources) > 0 {
			sources := film.Sources
			if strings.HasSuffix(serverID, "-srv-2") && len(sources) > 1 {
				sources = []model.Source{sources[1], sources[0]}
			}
			return &model.StreamResult{
				Sources:   sources,
				Subtitles: film.Subtitles,
			}, nil
		}
	}

	// 4. Return clean error - zero fake fallback videos
	return nil, fmt.Errorf("no verified video stream found for %q across any provider", title)
}
