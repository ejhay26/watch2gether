package scraper

import "github.com/ejhay26/watch2gether/backend/internal/model"

type MediaType = model.MediaType

const (
	MediaTypeMovie = model.MediaTypeMovie
	MediaTypeTV    = model.MediaTypeTV
)

type MediaItem = model.MediaItem
type MediaDetails = model.MediaDetails
type Episode = model.Episode
type Server = model.Server
type Subtitle = model.Subtitle
type Source = model.Source
type StreamResult = model.StreamResult

type Scraper interface {
	Search(query string) ([]MediaItem, error)
	GetTrending() ([]MediaItem, error)
	GetDetails(id string) (*MediaDetails, error)
	GetEpisodes(id string, season int) ([]Episode, error)
	GetServers(episodeId string) ([]Server, error)
	GetStream(serverId string) (*StreamResult, error)
}
