package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
)

//go:embed app.zip
var appData []byte

func main() {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		localAppData = os.TempDir()
	}

	h := sha256.Sum256(appData)
	hashStr := hex.EncodeToString(h[:8])

	targetDir := filepath.Join(localAppData, "Watch2Gether", "app_"+hashStr)
	exePath := filepath.Join(targetDir, "watch2gether.exe")
	serverPath := filepath.Join(targetDir, "server.exe")

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

	// 1. Start Go Fiber Companion Server if bundled and not already running
	var serverCmd *exec.Cmd
	if _, err := os.Stat(serverPath); err == nil {
		conn, err := net.DialTimeout("tcp", "127.0.0.1:8080", 250*time.Millisecond)
		if err != nil {
			// Port 8080 is not active, spawn server.exe silently
			serverCmd = exec.Command(serverPath)
			serverCmd.Dir = targetDir
			serverCmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
			_ = serverCmd.Start()
		} else {
			conn.Close()
		}
	}

	// 2. Launch Flutter GUI (Visible, beautiful splash & main window)
	appCmd := exec.Command(exePath, os.Args[1:]...)
	appCmd.Dir = targetDir
	_ = appCmd.Start()

	// 3. Wait for Flutter app to exit, then terminate companion server
	if appCmd.Process != nil {
		_ = appCmd.Wait()
	}
	if serverCmd != nil && serverCmd.Process != nil {
		_ = serverCmd.Process.Kill()
	}
}
