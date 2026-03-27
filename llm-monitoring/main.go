package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Model state
type model struct {
	projectPath string
	width        int
	height       int
	running      bool
	paused       bool
	lastUpdate   time.Time
	spinner      spinner.Model
	styles       styles
}

// Colors and styles
type styles struct {
	title       lipgloss.Style
	project     lipgloss.Style
	branch      lipgloss.Style
	path        lipgloss.Style
	section     lipgloss.Style
	label       lipgloss.Style
	vram        lipgloss.Style
	ram         lipgloss.Style
	git         lipgloss.Style
	commit      lipgloss.Style
	divider     lipgloss.Style
	help        lipgloss.Style
	errorMsg    lipgloss.Style
}

func newStyles() styles {
	s := styles{}
	s.title = lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("38")).
		MarginBottom(1)

	s.project = lipgloss.NewStyle().Foreground(lipgloss.Color("38")).Bold(true)
	s.branch = lipgloss.NewStyle().Foreground(lipgloss.Color("5"))
	s.path = lipgloss.NewStyle().Foreground(lipgloss.Color("4"))

	s.section = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("252"))
	s.label = lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	s.vram = lipgloss.NewStyle().Foreground(lipgloss.Color("10"))
	s.ram = lipgloss.NewStyle().Foreground(lipgloss.Color("10"))
	s.git = lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
	s.commit = lipgloss.NewStyle().Foreground(lipgloss.Color("38"))
	s.divider = lipgloss.NewStyle().
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("238"))

	s.help = lipgloss.NewStyle().
		MarginTop(2).
		Bold(true).
		Foreground(lipgloss.Color("252"))

	s.errorMsg = lipgloss.NewStyle().
		Foreground(lipgloss.Color("196"))

	return s
}

// Progress bar component
func progressBar(percent, width int) string {
	filled := (percent * width) / 100
	empty := width - filled

	var sb strings.Builder
	sb.WriteString("[")

	for i := 0; i < filled; i++ {
		sb.WriteString("#")
	}
	for i := 0; i < empty; i++ {
		sb.WriteString("-")
	}
	sb.WriteString(fmt.Sprintf("] %3d%%", percent))

	return sb.String()
}

// Color for progress bar based on percentage
func progressStyle(percent int) lipgloss.Style {
	if percent >= 80 {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("196")) // Red
	} else if percent >= 60 {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("220")) // Yellow
	}
	return lipgloss.NewStyle().Foreground(lipgloss.Color("70")) // Green
}

// Get VRAM usage
func getVRAMUsage() (int, string) {
	cmd := exec.Command("nvidia-smi", "--query-gpu=memory.used,memory.total", "--format=csv,noheader,nounits")
	output, err := cmd.Output()
	if err != nil {
		return 0, "GPU not detected"
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) < 1 {
		return 0, "GPU not detected"
	}

	parts := strings.Split(lines[0], ",")
	if len(parts) < 2 {
		return 0, "GPU not detected"
	}

	used, _ := strconv.Atoi(strings.TrimSpace(parts[0]))
	total, _ := strconv.Atoi(strings.TrimSpace(parts[1]))

	if total == 0 {
		return 0, "GPU not detected"
	}

	percent := (used * 100) / total
	return percent, fmt.Sprintf("%d / %d MB", used, total)
}

// Get GPU temperature
func getGPUTemp() string {
	cmd := exec.Command("nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits")
	output, err := cmd.Output()
	if err != nil {
		return "N/A"
	}
	return strings.TrimSpace(string(output))
}

// Get GPU fan speed
func getGPUFan() string {
	cmd := exec.Command("nvidia-smi", "--query-gpu=fan.speed", "--format=csv,noheader,nounits")
	output, err := cmd.Output()
	if err != nil {
		return "N/A"
	}
	return strings.TrimSpace(string(output)) + "%"
}

// Get RAM usage
func getRAMUsage() (int, string) {
	cmd := exec.Command("free", "b")
	output, err := cmd.Output()
	if err != nil {
		return 0, "N/A"
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) < 2 {
		return 0, "N/A"
	}

	fields := strings.Fields(lines[1])
	if len(fields) < 3 {
		return 0, "N/A"
	}

	total, _ := strconv.Atoi(fields[1])
	used, _ := strconv.Atoi(fields[2])

	if total == 0 {
		return 0, "N/A"
	}

	percent := (used * 100) / total
	return percent, fmt.Sprintf("%d / %d MB", used, total)
}

// Get uncommitted lines
func getUncommittedLines(path string) string {
	cmd := exec.Command("git", "diff", "--numstat")
	cmd.Dir = path
	output, err := cmd.Output()
	if err != nil {
		return "Not a git repo"
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	total := 0
	for _, line := range lines {
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) >= 2 {
			added, _ := strconv.Atoi(fields[0])
			removed, _ := strconv.Atoi(fields[1])
			total += added + removed
		}
	}

	return strconv.Itoa(total)
}

// Get commit count ahead/behind
func getCommitCount(path string) string {
	currentBranchCmd := exec.Command("git", "branch", "--show-current")
	currentBranchCmd.Dir = path
	output, err := currentBranchCmd.Output()
	if err != nil {
		return "N/A"
	}

	branch := strings.TrimSpace(string(output))
	if branch == "" {
		return "N/A"
	}

	cmd := exec.Command("git", "rev-list", "--count", "HEAD..origin/"+branch)
	cmd.Dir = path
	aheadOutput, err := cmd.Output()
	ahead := 0
	if err == nil {
		ahead, _ = strconv.Atoi(strings.TrimSpace(string(aheadOutput)))
	}

	cmd2 := exec.Command("git", "rev-list", "--count", "origin/"+branch+"..HEAD")
	cmd2.Dir = path
	behindOutput, err := cmd2.Output()
	behind := 0
	if err == nil {
		behind, _ = strconv.Atoi(strings.TrimSpace(string(behindOutput)))
	}

	return fmt.Sprintf("Ahead: %d | Behind: %d", ahead, behind)
}

// Get time since last commit
func getTimeSinceLastCommit(path string) string {
	cmd := exec.Command("git", "log", "-1", "--format=%ai")
	cmd.Dir = path
	output, err := cmd.Output()
	if err != nil {
		return "N/A"
	}

	lastCommit, _ := time.Parse("2006-01-02 15:04:05 -0700", strings.TrimSpace(string(output)))
	now := time.Now()
	diff := now.Sub(lastCommit)

	days := int(diff.Hours()) / 24
	hours := int(diff.Hours()) % 24
	mins := int(diff.Minutes()) % 60

	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm ago", days, hours, mins)
	} else if hours > 0 {
		return fmt.Sprintf("%dh %dm ago", hours, mins)
	}
	return fmt.Sprintf("%dm ago", mins)
}

// Get recent commits
func getRecentCommits(path string, limit int) []string {
	cmd := exec.Command("git", "log", "-n", fmt.Sprintf("%d", limit), "--format=%ai | %s")
	cmd.Dir = path
	output, err := cmd.Output()
	if err != nil {
		return []string{"No commits found"}
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 0 {
		return []string{"No commits found"}
	}

	return lines
}

// Update message
type updateMsg struct{}

func tick() tea.Msg {
	return updateMsg{}
}

func initialModel(projectPath string) model {
	s := newStyles()
	s.divider = s.divider.Width(s.width)

	m := model{
		projectPath: projectPath,
		running:     true,
		paused:      false,
		lastUpdate:  time.Now(),
		spinner:     spinner.New(),
		styles:      s,
	}
	m.spinner.Style = m.styles.vram
	return m
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		spinner.Tick,
		tea.Every(time.Second, func(t time.Time) tea.Msg {
			return updateMsg{}
		}),
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			m.lastUpdate = time.Now()
		case "h":
			return m, tea.Batch(tea.Println(m.styles.help.Render("Keyboard Controls: q=quit, r=refresh, h=help, space=pause")))
		case " ":
			m.paused = !m.paused
		}
		return m, nil

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.styles.divider = m.styles.divider.Width(msg.Width)
		return m, nil

	case updateMsg:
		if !m.paused {
			m.lastUpdate = time.Now()
			return m, nil
		}
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	default:
		return m, nil
	}
}

func (m model) View() string {
	var sb strings.Builder

	// Header
	sb.WriteString(m.styles.title.Render("  _    _                      ____  _             _    \n"+
		" | |  | |                    |  _ \\| |           | |   \n"+
		" | |__| | ___  __ _ _ __ ___  | |_) | | __ _ _ __ | |_  \n"+
		" |  __  |/ _ \\| `_` | '__/ _ \\ |  _ <| |/ _` | '_ \\| __| \n"+
		" | |  | |  __/ (_| | | |  __/ | |_) | | (_| | | | | |_  \n"+
		" |_|  |_|\\___|\\__,_|_|  \\___| |____/|_|\\__,_|_| |_|_\\__| "))

	sb.WriteString("\n")

	// Project info
	sb.WriteString(m.styles.project.Render("Project:") + " " +
		m.styles.path.Render(getProjectName(m.projectPath)) + "\n")

	branchCmd := exec.Command("git", "branch", "--show-current")
	branchCmd.Dir = m.projectPath
	branchOutput, err := branchCmd.Output()
	if err == nil {
		sb.WriteString(m.styles.branch.Render("Branch:") + " " +
			m.styles.branch.Render(strings.TrimSpace(string(branchOutput))) + "\n")
	}

	sb.WriteString(m.styles.path.Render("Path:") + " " +
		m.styles.path.Render(m.projectPath) + "\n")

	sb.WriteString(m.styles.divider.Render(strings.Repeat("=", 60)) + "\n")

	// Resource usage
	sb.WriteString("\n" + m.styles.section.Render("=== Resource Usage ===") + "\n\n")

	vram, vramInfo := getVRAMUsage()
	if vram > 0 {
		sb.WriteString(m.styles.label.Render("VRAM:") + " " +
			progressBar(vram, 30) + "\n")
		sb.WriteString(m.styles.vram.Render(fmt.Sprintf("  %s\n", vramInfo)))

		temp := getGPUTemp()
		fan := getGPUFan()
		sb.WriteString(fmt.Sprintf("  Temp: %s°C   Fan: %s\n",
			m.styles.vram.Render(temp),
			m.styles.vram.Render(fan)))
	} else {
		sb.WriteString(m.styles.label.Render("VRAM:") + " " +
			m.styles.errorMsg.Render("GPU not detected") + "\n")
	}

	sb.WriteString("\n")

	ram, ramInfo := getRAMUsage()
	if ram > 0 {
		sb.WriteString(m.styles.label.Render("RAM:") + " " +
			progressBar(ram, 30) + "\n")
		sb.WriteString(m.styles.ram.Render(fmt.Sprintf("  %s\n", ramInfo)))
	} else {
		sb.WriteString(m.styles.label.Render("RAM:") + " " +
			m.styles.errorMsg.Render("N/A") + "\n")
	}

	sb.WriteString("\n")

	// Git section
	sb.WriteString(m.styles.section.Render("=== Git Statistics ===") + "\n\n")

	uncommitted := getUncommittedLines(m.projectPath)
	if uncommitted != "Not a git repo" {
		sb.WriteString(m.styles.label.Render("Uncommitted Lines:") + " " +
			m.styles.git.Render(uncommitted) + "\n")
	} else {
		sb.WriteString(m.styles.label.Render("Uncommitted Lines:") + " " +
			m.styles.errorMsg.Render(uncommitted) + "\n")
	}

	commitCount := getCommitCount(m.projectPath)
	sb.WriteString(m.styles.label.Render("Commit Status:") + " " +
		m.styles.git.Render(commitCount) + "\n")

	timeSince := getTimeSinceLastCommit(m.projectPath)
	sb.WriteString(m.styles.label.Render("Last Commit:") + " " +
		m.styles.branch.Render(timeSince) + "\n")

	sb.WriteString("\n")

	// Commit list
	sb.WriteString(m.styles.section.Render("=== Recent Commits ===") + "\n\n")

	commits := getRecentCommits(m.projectPath, 5)
	for _, commit := range commits {
		sb.WriteString(m.styles.commit.Render(commit) + "\n")
	}

	sb.WriteString("\n" + m.styles.divider.Render(strings.Repeat("=", 60)) + "\n")

	// Status footer
	if m.paused {
		sb.WriteString(m.styles.help.Render("PAUSED - Press SPACE to resume"))
	} else {
		sb.WriteString(m.styles.help.Render("Press q to quit | r to refresh | h for help | space to pause"))
		sb.WriteString("\n" + m.styles.help.Render("Auto-refresh: 5 seconds"))
	}

	return sb.String()
}

func getProjectName(path string) string {
	parts := strings.Split(path, "/")
	if len(parts) > 0 {
		return parts[len(parts)-1]
	}
	return path
}

func main() {
	var projectPath string

	fmt.Println("\n" + newStyles().help.Render("Enter project directory path:"))
	fmt.Print("> ")
	fmt.Scanln(&projectPath)

	if projectPath == "" {
		fmt.Println(newStyles().errorMsg.Render("No path provided. Exiting."))
		os.Exit(1)
	}

	// Resolve to absolute path
	absPath, err := exec.Command("cd", projectPath, "&&", "pwd").Output()
	if err != nil {
		fmt.Println(newStyles().errorMsg.Render("Path does not exist: " + projectPath))
		os.Exit(1)
	}
	projectPath = strings.TrimSpace(string(absPath))

	// Check if it's a directory
	info, err := os.Stat(projectPath)
	if err != nil || !info.IsDir() {
		fmt.Println(newStyles().errorMsg.Render("Path does not exist: " + projectPath))
		os.Exit(1)
	}

	p := tea.NewProgram(initialModel(projectPath), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error running program: %v\n", err)
		os.Exit(1)
	}
}
