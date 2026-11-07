// Linux-Check.exe is a thin launcher: it unpacks the embedded, read-only
// PowerShell script and device list into a temp folder, runs the script with
// the system's own PowerShell, and deletes the temp folder afterwards.
// Everything the program does is in Linux-Check.ps1.
package main

import (
	"bufio"
	"embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

//go:embed Linux-Check.ps1 devices.json
var files embed.FS

func main() {
	code := run()
	pause()
	os.Exit(code)
}

func run() int {
	tmp, err := os.MkdirTemp("", "linuxcheck")
	if err != nil {
		fmt.Println("Error:", err)
		return 1
	}
	defer os.RemoveAll(tmp)

	for _, name := range []string{"Linux-Check.ps1", "devices.json"} {
		data, _ := files.ReadFile(name)
		if err := os.WriteFile(filepath.Join(tmp, name), data, 0o600); err != nil {
			fmt.Println("Error:", err)
			return 1
		}
	}

	// Use the full path to Windows PowerShell so a powershell.exe sitting in
	// the current folder or on PATH can never be run instead.
	root := os.Getenv("SystemRoot")
	if root == "" {
		root = `C:\Windows`
	}
	ps := filepath.Join(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")

	// The report file goes next to the .exe, where the user can find it.
	outDir := "."
	if exe, err := os.Executable(); err == nil {
		outDir = filepath.Dir(exe)
	}

	cmd := exec.Command(ps, "-NoProfile", "-ExecutionPolicy", "Bypass",
		"-File", filepath.Join(tmp, "Linux-Check.ps1"))
	cmd.Env = append(os.Environ(), "LINUXCHECK_OUT="+outDir)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := cmd.Run(); err != nil {
		fmt.Println("Could not run PowerShell:", err)
		return 1
	}
	return 0
}

func pause() {
	fmt.Print("\nPress Enter to close...")
	bufio.NewReader(os.Stdin).ReadString('\n')
}
