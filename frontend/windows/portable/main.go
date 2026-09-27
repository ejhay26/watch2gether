package main

import (
	"archive/zip"
	"bytes"
	_ "embed"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

//go:embed app.zip
var appData []byte

func main() {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		localAppData = os.TempDir()
	}

	targetDir := filepath.Join(localAppData, "Watch2Gether", "app_v1.0.6")
	exePath := filepath.Join(targetDir, "watch2gether.exe")

	needExtract := false
	if fi, err := os.Stat(exePath); os.IsNotExist(err) || fi.Size() == 0 {
		needExtract = true
	}

	if needExtract {
		_ = os.MkdirAll(targetDir, 0755)
		r, err := zip.NewReader(bytes.NewReader(appData), int64(len(appData)))
		if err == nil {
			for _, f := range r.File {
				destPath := filepath.Join(targetDir, f.Name)
				if f.FileInfo().IsDir() {
					_ = os.MkdirAll(destPath, 0755)
					continue
				}
				_ = os.MkdirAll(filepath.Dir(destPath), 0755)
				dst, err := os.OpenFile(destPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
				if err != nil {
					continue
				}
				src, err := f.Open()
				if err != nil {
					dst.Close()
					continue
				}
				_, _ = io.Copy(dst, src)
				src.Close()
				dst.Close()
			}
		}
	}

	cmd := exec.Command(exePath, os.Args[1:]...)
	cmd.Dir = targetDir
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	_ = cmd.Start()
}
