# LLM CLI Tool -- Specifications

## Overview

A minimal Java Swing desktop application that lets a user register, browse, edit, and inspect named command-line templates for running local LLM inference. The core problem it solves: repeatedly typing or copying long command lines with frequently-changing parameters (model path, context length, temperature, etc.). Each command is stored as a named entry on disk; the GUI provides a clean table view with inline editing of content and comments via independent popups.

## 1. Scope

### 1.1 What the application does

- Present a scrollable table of registered commands (name + comment).
- Allow the user to add new commands with a name, optional body, and optional comment.
- Let the user open a writable popup to view/edit a command's body by clicking its name.
- Let the user open a writable popup to view/edit a command's comment by clicking its comment.
- Multiple popups may be open simultaneously.
- Persist all data in a file-based format in the current working directory.
- Provide a menu bar with: Add command, Help, and Color configuration.
- Window is resizable. Design is minimalist.

### 1.2 What the application does not do

- No execution of commands. The tool is a template library, not a runner.
- No networking or remote sync.
- No authentication or multi-user support.
- No import/export (beyond raw file access).
- No command history or versioning.

## 2. Tech Stack

| Concern | Choice |
|---------|--------|
| Language | Java (JDK 17+) |
| GUI | javax.swing (native Swing, no third-party UI libs) |
| Build | Maven |
| Packaging | Single executable JAR (`maven-jar-plugin` with `mainClass`) |
| Launcher | Bash script (optional, runs `java -jar`) |
| OS | Linux (primary), cross-platform compatible |

## 3. Data Model

### 3.1 Command entity

A command has three fields:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| name | String | Yes | Unique identifier. Used as filename. Alphanumeric, hyphens, underscores only. |
| body | String | No | The raw command-line text. May be multi-line. May be empty. |
| comment | String | No | Free-text description. May be multi-line. May be empty. |

### 3.2 File-based storage

- Commands are stored in a directory named `commands/` relative to the working directory at startup.
- Each command is one file named `<name>.cmd` inside `commands/`.
- File format is a plain text file with a delimiter-based structure:

```
#NAME:<command_name>
#BODY:
<command body text, may span multiple lines>
#END_BODY
#COMMENT:
<comment text, may span multiple lines>
#END_COMMENT
```

- The `#BODY:` and `#END_BODY` delimiters bound the body section. If the body is empty, the two delimiters appear on consecutive lines with nothing between them.
- The `#COMMENT:` and `#END_COMMENT` delimiters bound the comment section. Same rule for empty comments.
- The `#NAME:` line is always the first non-empty line and repeats the filename stem for validation purposes.
- On load, the application reads all `*.cmd` files in `commands/`, parses them, and populates the table.
- On save (from a popup), the application writes the file immediately.

### 3.3 Storage conventions

- `commands/` is created on first launch if it does not exist.
- Name uniqueness is enforced: the user cannot add a command whose name already exists as a file in `commands/`.
- Name validation: only `[a-zA-Z0-9_-]+` is accepted. Invalid characters are rejected with a dialog message.

## 4. User Interface

### 4.1 Main window

- **Title:** "LLM CLI Tool" (default, not configurable).
- **Size:** 800x500 default, resizable by the user in any direction.
- **Minimum size:** 400x200.
- **Layout:**
  - A `JMenuBar` at the top.
  - A `JScrollPane` containing a `JTable` that fills the remaining client area.
- **Default close operation:** `EXIT_ON_CLOSE`.

### 4.2 Table

The table has two columns:

| Column | Width behavior | Content | Clickable? |
|--------|---------------|---------|------------|
| Name | 200px preferred, resizable | Command name | Yes -- opens body popup |
| Comment | Fill remaining width | Command comment (truncated to one line in cell display) | Yes -- opens comment popup |

- Table rows are not editable inline. Editing happens via popups.
- Rows are sorted alphabetically by name (ascending) at load time.
- Row height: default Swing row height (22-24px).
- Clicking on the empty row area (if any) does nothing.

### 4.3 Menu bar

A single top-level menu labeled **Tools**:

| Menu item | Action |
|-----------|--------|
| Add command... | Opens the "Add command" dialog (see 4.4) |
| Help | Opens the "Help" dialog (see 4.6) |
| Color config | Opens the "Color configuration" dialog (see 4.7) |

### 4.4 Add command dialog

- Modal `JDialog`.
- Size: 500x300, non-resizable.
- Fields (top to bottom):

  1. **Name** -- `JTextField`, required, max 128 chars. Label: "Name:"
  2. **Body** -- `JTextArea` inside `JScrollPane`, 5 rows visible, line wrap ON, wrap style word. Label: "Body:"
  3. **Comment** -- `JTextArea` inside `JScrollPane`, 3 rows visible, line wrap ON, wrap style word. Label: "Comment:"

- Buttons (right-aligned at bottom):
  - **Save** -- validates name, writes file, refreshes table, closes dialog.
  - **Cancel** -- discards, closes dialog.

- Validation:
  - Name must match `[a-zA-Z0-9_-]+` and must not already exist in `commands/`.
  - Body and comment may be empty.
  - On invalid name, a `JOptionPane` error dialog is shown; the dialog stays open.

### 4.5 Edit popups (body and comment)

When the user clicks a command name or comment in the table, a new independent window appears:

- Non-modal `JWindow`-based frame (`JFrame` without menu bar).
- Title: `"[CommandName] -- Body"` or `"[CommandName] -- Comment"`.
- Size: 600x400 default, resizable.
- Content:
  - A `JTextArea` with line wrap ON, fill the client area inside a `JScrollPane`.
  - Pre-populated with the current body or comment text.
  - Writable.
- Buttons (bottom-right):
  - **Save** -- writes the edited text back to the file, refreshes the table cell, closes popup.
  - **Close** -- discards changes, closes popup.

- Multiple popups may be open simultaneously. Each popup tracks which command and which field (body/comment) it edits.
- If the underlying file was modified by another popup (e.g., two body popups for the same command), the last save wins. No conflict detection is required.

### 4.6 Help dialog

- Modal `JDialog`.
- Size: 450x350, non-resizable.
- Content (non-editable `JTextArea`, read-only):

  ```
  LLM CLI Tool
  ============

  A simple command-line template manager for local LLM inference.

  Usage:
  - Tools > Add command... to register a new command.
  - Click a command's name to view/edit its body.
  - Click a command's comment to view/edit its comment.
  - Tools > Color config to adjust UI colors.

  Commands are stored as files in the ./commands/ directory.
  Each file uses a simple delimited text format.
  ```

- Button: **OK** (closes dialog).

### 4.7 Color configuration dialog

- Modal `JDialog`.
- Size: 400x350, non-resizable.
- Controls:

  | Control | Type | Default |
  |---------|------|---------|
  | Background color | `JColorChooser` or `JButton` that opens `JColorChooser` | System default |
  | Text color | Same pattern | System default |
  | Selection color | Same pattern | System default |

- Buttons:
  - **Apply** -- applies colors to the main window and table immediately. Does not close dialog.
  - **Reset** -- reverts to system defaults. Does not close dialog.
  - **Close** -- closes dialog.

- Colors are NOT persisted to disk. They apply for the current session only.

## 5. Application Lifecycle

### 5.1 Startup

1. Application starts, creates/shows the main `JFrame`.
2. Scans `./commands/` directory (creates it if missing).
3. Reads and parses all `*.cmd` files.
4. Populates the table model and sorts by name.
5. Table is displayed.

### 5.2 Runtime

- Table refreshes after any add, save, or file write operation.
- Refresh means: re-read `commands/`, rebuild the table model, sort by name.
- Open popups are NOT closed on table refresh. They retain their own copy of the data until the user clicks Save or Close.

### 5.3 Shutdown

- `EXIT_ON_CLOSE` on the main frame.
- No save prompt on close. All data is saved immediately on each write.

## 6. Build and Packaging

### 6.1 Maven structure

```
llm_cli_tool/
  ├── specifications.md
  ├── pom.xml
  ├── src/
  │   └── main/
  │       └── java/
  │           └── com/
  │               └── llmcli/
  │                   ├── Main.java
  │                   ├── model/
  │                   │   └── Command.java
  │                   ├── storage/
  │                   │   └── CommandStore.java
  │                   └── gui/
  │                       ├── MainWindow.java
  │                       ├── AddCommandDialog.java
  │                       ├── EditPopup.java
  │                       ├── HelpDialog.java
  │                       └── ColorConfigDialog.java
  └── launcher.sh
```

### 6.2 pom.xml

- `groupId`: `com.llmcli`
- `artifactId`: `llm-cli-tool`
- `version`: `1.0.0`
- `packaging`: `jar`
- `source`/`target`: Java 17
- No third-party dependencies. Only `javax.swing` and standard library.
- `maven-jar-plugin` sets `Main-Class` to `com.llmcli.Main`.
- `maven-compiler-plugin` sets release to 17.

### 6.3 launcher.sh

A bash script at the project root that:

1. Checks that the JAR exists (`target/llm-cli-tool-1.0.0.jar`).
2. Runs `java -jar target/llm-cli-tool-1.0.0.jar` from the current directory.
3. Requires no arguments.

Executable (`chmod +x`).

### 6.4 Build commands

```bash
mvn clean package        # Build JAR
./launcher.sh            # Run via launcher
java -jar target/llm-cli-tool-1.0.0.jar   # Run directly
```

## 7. Non-Functional Requirements

| Property | Constraint |
|----------|-----------|
| Performance | Table refresh for up to 500 commands must complete within 500ms. |
| Memory | Application idle memory under 100MB. |
| Portability | Runs on any Linux distro with JDK 17+. No native dependencies beyond what JRE provides. |
| Look-and-feel | Uses the system default LookAndFeel (`UIManager.getSystemLookAndFeelClassName()`), with a fallback to `javax.swing.plaf.metal.MetalLookAndFeel`. |
| Error handling | Unhandled exceptions show a `JOptionPane` error dialog with the message, then allow the application to continue. |

## 8. Constraints and Decisions

- **No external dependencies.** Pure Swing + standard Java.
- **No persistence for colors.** Session-only UI theming.
- **No delete or rename.** Commands can only be added. If the user wants to remove one, they delete the file from `commands/` manually. The application does not provide a delete button.
- **File-based, not database.** Simple text files with delimiters. Human-readable and editable outside the tool.
- **No validation of command body content.** The body is treated as raw text. The tool does not interpret or validate shell syntax.
- **Single-user, single-session.** No concurrency or locking mechanisms beyond last-write-wins.
