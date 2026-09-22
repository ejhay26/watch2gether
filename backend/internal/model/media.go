package model

type MediaType string

const (
	MediaTypeMovie MediaType = "movie"
	MediaTypeTV    MediaType = "tv"
)

type MediaItem struct {
	ID           string    `json:"id"`
	Title        string    `json:"title"`
	Type         MediaType `json:"type"`
	Poster       string    `json:"poster"`
	Banner       string    `json:"banner,omitempty"`
	Year         string    `json:"year,omitempty"`
	Rating       string    `json:"rating,omitempty"`
	RatingSource string    `json:"rating_source,omitempty"`
	Quality      string    `json:"quality,omitempty"`
	Duration     string    `json:"duration,omitempty"`
	Overview     string    `json:"overview,omitempty"`
}

type MediaDetails struct {
	MediaItem
	Genres        []string `json:"genres,omitempty"`
	Cast          []string `json:"cast,omitempty"`
	Seasons       []int    `json:"seasons,omitempty"`
	TotalEpisodes int      `json:"total_episodes,omitempty"`
}

type Episode struct {
	ID       string `json:"id"`
	Number   int    `json:"number"`
	Season   int    `json:"season"`
	Title    string `json:"title"`
	Overview string `json:"overview,omitempty"`
}

type Server struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	ServerID int    `json:"server_id,omitempty"`
}

type Subtitle struct {
	URL  string `json:"url"`
	Lang string `json:"lang"`
}

type Source struct {
	URL     string `json:"url"`
	Quality string `json:"quality"`
	IsM3U8  bool   `json:"is_m3u8"`
}

type StreamResult struct {
	Sources   []Source          `json:"sources"`
	Subtitles []Subtitle        `json:"subtitles"`
	Headers   map[string]string `json:"headers,omitempty"`
}
