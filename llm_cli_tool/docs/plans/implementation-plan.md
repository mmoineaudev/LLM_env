# LLM CLI Tool -- Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build a minimal Java Swing GUI app that registers, browses, and edits named command-line templates stored as delimited text files on disk.

**Architecture:** Single JAR, zero external dependencies. Model-View split: `model.Command` (data), `storage.CommandStore` (file I/O), `gui.*` (Swing components). Main frame hosts a table; all editing happens in separate windows/dialogs.

**Tech Stack:** Java 17, javax.swing, Maven, bash launcher.

---

## Task 1: Create Maven project skeleton

**Objective:** Set up `pom.xml` with correct groupId, artifactId, Java 17 target, and jar plugin with mainClass.

**Files:**
- Create: `pom.xml`

**Step 1: Write pom.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.llmcli</groupId>
    <artifactId>llm-cli-tool</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>3.3.0</version>
                <configuration>
                    <archive>
                        <manifest>
                            <mainClass>com.llmcli.Main</mainClass>
                        </manifest>
                    </archive>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <release>17</release>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

**Step 2: Create directory structure**

```bash
mkdir -p src/main/java/com/llmcli/model
mkdir -p src/main/java/com/llmcli/storage
mkdir -p src/main/java/com/llmcli/gui
```

**Step 3: Verify build**

```bash
mvn clean compile
```

Expected: BUILD SUCCESS, no errors.

**Step 4: Commit**

```bash
git add pom.xml src/
git commit -m "init: Maven project skeleton with Java 17"
```

---

## Task 2: Implement Command model class

**Objective:** Create the data class representing a single command entry.

**Files:**
- Create: `src/main/java/com/llmcli/model/Command.java`

**Step 1: Write Command.java**

```java
package com.llmcli.model;

public class Command {
    private final String name;
    private String body;
    private String comment;

    public Command(String name, String body, String comment) {
        this.name = name;
        this.body = body != null ? body : "";
        this.comment = comment != null ? comment : "";
    }

    public String getName() { return name; }
    public String getBody() { return body; }
    public void setBody(String body) { this.body = body != null ? body : ""; }
    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment != null ? comment : ""; }

    @Override
    public String toString() {
        return "Command{name='" + name + "'}";
    }
}
```

**Step 2: Verify compile**

```bash
mvn clean compile
```

Expected: BUILD SUCCESS.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/model/Command.java
git commit -m "feat: add Command model class"
```

---

## Task 3: Implement CommandStore -- file format writer

**Objective:** Write the `CommandStore` class with `saveCommand` method that writes a `.cmd` file in the delimited format.

**Files:**
- Create: `src/main/java/com/llmcli/storage/CommandStore.java`

**Step 1: Write CommandStore.java (writer only for now)**

```java
package com.llmcli.storage;

import com.llmcli.model.Command;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

public class CommandStore {
    private static final Pattern NAME_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]+$");
    private static final String DIR_NAME = "commands";
    private final Path commandsDir;

    public CommandStore() {
        this.commandsDir = Path.of(DIR_NAME);
        ensureDir();
    }

    public CommandStore(Path baseDir) {
        this.commandsDir = baseDir.resolve(DIR_NAME);
        ensureDir();
    }

    private void ensureDir() {
        try {
            Files.createDirectories(commandsDir);
        } catch (IOException e) {
            throw new RuntimeException("Cannot create commands directory: " + commandsDir, e);
        }
    }

    public boolean isValidName(String name) {
        return name != null && NAME_PATTERN.matcher(name).matches();
    }

    public boolean nameExists(String name) {
        return Files.exists(commandsDir.resolve(name + ".cmd"));
    }

    public void saveCommand(Command cmd) {
        if (!isValidName(cmd.getName())) {
            throw new IllegalArgumentException("Invalid command name: " + cmd.getName());
        }

        String content = "#NAME:" + cmd.getName() + "\n"
                + "#BODY:\n"
                + cmd.getBody() + "\n"
                + "#END_BODY\n"
                + "#COMMENT:\n"
                + cmd.getComment() + "\n"
                + "#END_COMMENT\n";

        Path file = commandsDir.resolve(cmd.getName() + ".cmd");
        try {
            Files.writeString(file, content, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new RuntimeException("Failed to save command: " + cmd.getName(), e);
        }
    }

    // TODO: loadCommands() -- implemented in Task 4
}
```

**Step 2: Verify compile**

```bash
mvn clean compile
```

Expected: BUILD SUCCESS.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/storage/CommandStore.java
git commit -m "feat: CommandStore with saveCommand and name validation"
```

---

## Task 4: Implement CommandStore -- file format reader

**Objective:** Add `loadCommands` to read all `.cmd` files and return a sorted list of `Command` objects.

**Files:**
- Modify: `src/main/java/com/llmcli/storage/CommandStore.java`

**Step 1: Add loadCommands method**

Add this method to `CommandStore`:

```java
    public List<Command> loadCommands() {
        List<Command> commands = new ArrayList<>();

        try {
            Files.list(commandsDir)
                    .filter(p -> p.toString().endsWith(".cmd"))
                    .sorted()
                    .forEach(p -> {
                        try {
                            String content = Files.readString(p, StandardCharsets.UTF_8);
                            Command cmd = parseCommand(content);
                            if (cmd != null) commands.add(cmd);
                        } catch (IOException e) {
                            System.err.println("Skipping unreadable file: " + p.getFileName());
                        }
                    });
        } catch (IOException e) {
            System.err.println("Cannot list commands directory: " + e.getMessage());
        }

        return commands;
    }

    private Command parseCommand(String content) {
        String[] lines = content.split("\n");
        String name = "";
        StringBuilder body = new StringBuilder();
        StringBuilder comment = new StringBuilder();

        int mode = 0; // 0=header, 1=body, 2=comment
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.startsWith("#NAME:")) {
                name = trimmed.substring(6).trim();
            } else if (trimmed.equals("#BODY:")) {
                mode = 1;
            } else if (trimmed.equals("#END_BODY")) {
                mode = 0;
            } else if (trimmed.equals("#COMMENT:")) {
                mode = 2;
            } else if (trimmed.equals("#END_COMMENT")) {
                mode = 0;
            } else if (mode == 1) {
                if (body.length() > 0) body.append("\n");
                body.append(line);
            } else if (mode == 2) {
                if (comment.length() > 0) comment.append("\n");
                comment.append(line);
            }
        }

        if (!name.isEmpty()) {
            return new Command(name, body.toString().trim(), comment.toString().trim());
        }
        return null;
    }
```

**Step 2: Verify compile**

```bash
mvn clean compile
```

Expected: BUILD SUCCESS.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/storage/CommandStore.java
git commit -m "feat: CommandStore.loadCommands with delimited file parser"
```

---

## Task 5: Implement MainWindow -- frame and table

**Objective:** Build the main window with a scrollable two-column table (Name, Comment).

**Files:**
- Create: `src/main/java/com/llmcli/gui/MainWindow.java`

**Step 1: Write MainWindow.java**

```java
package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.util.List;

public class MainWindow {
    private JFrame frame;
    private JTable table;
    private DefaultTableModel tableModel;
    private CommandStore store;
    private JMenuBar menuBar;

    public MainWindow() {
        store = new CommandStore();
        initUI();
        refreshTable();
    }

    private void initUI() {
        frame = new JFrame("LLM CLI Tool");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setPreferredSize(new Dimension(800, 500));
        frame.setMinimumSize(new Dimension(400, 200));

        // Table model
        tableModel = new DefaultTableModel(new Object[]{"Name", "Comment"}, 0) {
            @Override
            public boolean isCellEditable(int row, int col) {
                return false;
            }
        };
        table = new JTable(tableModel);
        table.getColumnModel().getColumn(0).setPreferredWidth(200);

        JScrollPane scrollPane = new JScrollPane(table);
        frame.setLayout(new BorderLayout());
        frame.add(scrollPane, BorderLayout.CENTER);

        // Menu bar
        menuBar = new JMenuBar();
        frame.setJMenuBar(menuBar);

        // Click handlers
        table.addMouseListener(new java.awt.event.MouseAdapter() {
            @Override
            public void mouseClicked(java.awt.event.MouseEvent e) {
                int row = table.rowAtPoint(e.getPoint());
                int col = table.columnAtPoint(e.getPoint());
                if (row < 0) return;

                String name = (String) tableModel.getValueAt(row, 0);
                List<Command> commands = store.loadCommands();
                Command cmd = commands.stream()
                        .filter(c -> c.getName().equals(name))
                        .findFirst().orElse(null);
                if (cmd == null) return;

                if (col == 0) {
                    // Click on name -> open body popup
                    new EditPopup(frame, cmd, EditPopup.Mode.BODY);
                } else if (col == 1) {
                    // Click on comment -> open comment popup
                    new EditPopup(frame, cmd, EditPopup.Mode.COMMENT);
                }
            }
        });
    }

    public void refreshTable() {
        tableModel.setRowCount(0);
        List<Command> commands = store.loadCommands();
        for (Command cmd : commands) {
            tableModel.addRow(new Object[]{cmd.getName(), cmd.getComment()});
        }
    }

    public JMenuBar getMenuBar() { return menuBar; }
    public JFrame getFrame() { return frame; }

    public void show() {
        frame.pack();
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);
    }
}
```

**Step 2: Verify compile (will fail -- EditPopup not created yet)**

Skip compile check; this is resolved in Task 7.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/gui/MainWindow.java
git commit -m "feat: MainWindow with scrollable table and click handlers"
```

---

## Task 6: Implement AddCommandDialog

**Objective:** Modal dialog to add a new command with name, body, comment fields.

**Files:**
- Create: `src/main/java/com/llmcli/gui/AddCommandDialog.java`

**Step 1: Write AddCommandDialog.java**

```java
package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import java.awt.*;

public class AddCommandDialog extends JDialog {
    private final CommandStore store;
    private final Runnable onSaved;

    public AddCommandDialog(JFrame parent, CommandStore store, Runnable onSaved) {
        super(parent, "Add Command", true);
        this.store = store;
        this.onSaved = onSaved;
        initUI();
    }

    private void initUI() {
        setSize(500, 300);
        setResizable(false);
        setLocationRelativeTo(getParent());
       .setLayout(new BorderLayout(10, 10));

        // Form panel
        JPanel form = new JPanel(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.fill = gbc.HORIZONTAL;
        gbc.insets = new Insets(5, 5, 5, 5);
        gbc.gridx = 0; gbc.gridy = 0;

        // Name
        gbc.gridy = 0;
        form.add(new JLabel("Name:"), gbc);
        gbc.gridx = 1;
        JTextField nameField = new JTextField(30);
        form.add(nameField, gbc);

        // Body
        gbc.gridx = 0; gbc.gridy = 1;
        form.add(new JLabel("Body:"), gbc);
        gbc.gridx = 1;
        JTextArea bodyArea = new JTextArea(5, 30);
        bodyArea.setLineWrap(true);
        bodyArea.setWrapStyleWord(true);
        form.add(new JScrollPane(bodyArea), gbc);

        // Comment
        gbc.gridx = 0; gbc.gridy = 2;
        form.add(new JLabel("Comment:"), gbc);
        gbc.gridx = 1;
        JTextArea commentArea = new JTextArea(3, 30);
        commentArea.setLineWrap(true);
        commentArea.setWrapStyleWord(true);
        form.add(new JScrollPane(commentArea), gbc);

        add(form, BorderLayout.CENTER);

        // Buttons
        JPanel btnPanel = new JPanel(new FlowAlignment(FlowLayout.RIGHT));
        JButton saveBtn = new JButton("Save");
        JButton cancelBtn = new JButton("Cancel");

        saveBtn.addActionListener(e -> {
            String name = nameField.getText().trim();
            if (name.isEmpty() || !store.isValidName(name)) {
                JOptionPane.showMessageDialog(AddCommandDialog.this,
                        "Invalid name. Use only letters, digits, hyphens, and underscores.",
                        "Error", JOptionPane.ERROR_MESSAGE);
                return;
            }
            if (store.nameExists(name)) {
                JOptionPane.showMessageDialog(AddCommandDialog.this,
                        "Command '" + name + "' already exists.",
                        "Error", JOptionPane.ERROR_MESSAGE);
                return;
            }
            store.saveCommand(new Command(name, bodyArea.getText(), commentArea.getText()));
            onSaved.run();
            dispose();
        });

        cancelBtn.addActionListener(e -> dispose());

        btnPanel.add(saveBtn);
        btnPanel.add(cancelBtn);
        add(btnPanel, BorderLayout.SOUTH);
    }

    // Helper for right-aligned flow layout
    private static class FlowAlignment extends FlowLayout {
        FlowAlignment(int align) { super(align); }
    }
    }
```

Wait, that has a brace issue. Let me correct:

```java
package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import java.awt.*;

public class AddCommandDialog extends JDialog {
    private final CommandStore store;
    private final Runnable onSaved;

    public AddCommandDialog(JFrame parent, CommandStore store, Runnable onSaved) {
        super(parent, "Add Command", true);
        this.store = store;
        this.onSaved = onSaved;
        initUI();
    }

    private void initUI() {
        setSize(500, 300);
        setResizable(false);
        setLocationRelativeTo(getParent());
        setLayout(new BorderLayout(10, 10));

        JPanel form = new JPanel(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.insets = new Insets(5, 5, 5, 5);
        gbc.gridx = 0; gbc.gridy = 0;

        gbc.gridy = 0;
        form.add(new JLabel("Name:"), gbc);
        gbc.gridx = 1;
        JTextField nameField = new JTextField(30);
        form.add(nameField, gbc);

        gbc.gridx = 0; gbc.gridy = 1;
        form.add(new JLabel("Body:"), gbc);
        gbc.gridx = 1;
        JTextArea bodyArea = new JTextArea(5, 30);
        bodyArea.setLineWrap(true);
        bodyArea.setWrapStyleWord(true);
        form.add(new JScrollPane(bodyArea), gbc);

        gbc.gridx = 0; gbc.gridy = 2;
        form.add(new JLabel("Comment:"), gbc);
        gbc.gridx = 1;
        JTextArea commentArea = new JTextArea(3, 30);
        commentArea.setLineWrap(true);
        commentArea.setWrapStyleWord(true);
        form.add(new JScrollPane(commentArea), gbc);

        add(form, BorderLayout.CENTER);

        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.RIGHT));
        JButton saveBtn = new JButton("Save");
        JButton cancelBtn = new JButton("Cancel");

        saveBtn.addActionListener(e -> {
            String name = nameField.getText().trim();
            if (name.isEmpty() || !store.isValidName(name)) {
                JOptionPane.showMessageDialog(AddCommandDialog.this,
                        "Invalid name. Use only letters, digits, hyphens, and underscores.",
                        "Error", JOptionPane.ERROR_MESSAGE);
                return;
            }
            if (store.nameExists(name)) {
                JOptionPane.showMessageDialog(AddCommandDialog.this,
                        "Command '" + name + "' already exists.",
                        "Error", JOptionPane.ERROR_MESSAGE);
                return;
            }
            store.saveCommand(new Command(name, bodyArea.getText(), commentArea.getText()));
            onSaved.run();
            dispose();
        });

        cancelBtn.addActionListener(e -> dispose());

        btnPanel.add(saveBtn);
        btnPanel.add(cancelBtn);
        add(btnPanel, BorderLayout.SOUTH);
    }
}
```

**Step 2: Verify compile (will fail -- EditPopup not yet created, but this file compiles in isolation)**

Skip for now; full compile after Task 7.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/gui/AddCommandDialog.java
git commit -m "feat: AddCommandDialog with name validation and save"
```

---

## Task 7: Implement EditPopup

**Objective:** Non-modal popup window for editing a command's body or comment text. Multiple popups allowed simultaneously.

**Files:**
- Create: `src/main/java/com/llmcli/gui/EditPopup.java`

**Step 1: Write EditPopup.java**

```java
package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import java.awt.*;

public class EditPopup extends JFrame {
    public enum Mode { BODY, COMMENT }

    private final Command cmd;
    private final Mode mode;
    private final CommandStore store;
    private final Runnable onSaved;

    public EditPopup(JFrame parent, Command cmd, Mode mode) {
        this.cmd = cmd;
        this.mode = mode;
        this.store = new CommandStore();

        String suffix = mode == Mode.BODY ? "-- Body" : "-- Comment";
        setTitle(cmd.getName() + suffix);

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(600, 400);
        setLocationRelativeTo(parent);

        String initialText = mode == Mode.BODY ? cmd.getBody() : cmd.getComment();

        JTextArea textArea = new JTextArea(initialText);
        textArea.setLineWrap(true);
        textArea.setWrapStyleWord(true);

        JScrollPane scrollPane = new JScrollPane(textArea);
        add(scrollPane, BorderLayout.CENTER);

        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.RIGHT));

        onSaved = () -> {
            store.saveCommand(cmd);
            // Close after save
        };

        JButton saveBtn = new JButton("Save");
        saveBtn.addActionListener(e -> {
            String text = textArea.getText();
            if (mode == Mode.BODY) {
                cmd.setBody(text);
            } else {
                cmd.setComment(text);
            }
            store.saveCommand(cmd);
            onSaved.run();
            dispose();
        });

        JButton closeBtn = new JButton("Close");
        closeBtn.addActionListener(e -> dispose());

        btnPanel.add(saveBtn);
        btnPanel.add(closeBtn);
        add(btnPanel, BorderLayout.SOUTH);

        setVisible(true);
    }
}
```

**Step 2: Commit**

```bash
git add src/main/java/com/llmcli/gui/EditPopup.java
git commit -m "feat: EditPopup for body and comment editing"
```

---

## Task 8: Implement HelpDialog

**Objective:** Modal dialog showing usage instructions.

**Files:**
- Create: `src/main/java/com/llmcli/gui/HelpDialog.java`

**Step 1: Write HelpDialog.java**

```java
package com.llmcli.gui;

import javax.swing.*;
import java.awt.*;

public class HelpDialog extends JDialog {
    public HelpDialog(JFrame parent) {
        super(parent, "Help", true);
        initUI();
    }

    private void initUI() {
        setSize(450, 350);
        setResizable(false);
        setLocationRelativeTo(getParent());
        setLayout(new BorderLayout(10, 10));

        String text = "LLM CLI Tool\n"
                + "============\n\n"
                + "A simple command-line template manager for local LLM inference.\n\n"
                + "Usage:\n"
                + "- Tools > Add command... to register a new command.\n"
                + "- Click a command's name to view/edit its body.\n"
                + "- Click a command's comment to view/edit its comment.\n"
                + "- Tools > Color config to adjust UI colors.\n\n"
                + "Commands are stored as files in the ./commands/ directory.\n"
                + "Each file uses a simple delimited text format.";

        JTextArea textArea = new JTextArea(text);
        textArea.setEditable(false);
        textArea.setWrapStyleWord(true);
        textArea.setLineWrap(true);
        textArea.setFont(getFont().deriveFont((float) getFont().getSize()));

        JScrollPane scrollPane = new JScrollPane(textArea);
        add(scrollPane, BorderLayout.CENTER);

        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));
        JButton okBtn = new JButton("OK");
        okBtn.addActionListener(e -> dispose());
        btnPanel.add(okBtn);
        add(btnPanel, BorderLayout.SOUTH);
    }
}
```

**Step 2: Commit**

```bash
git add src/main/java/com/llmcli/gui/HelpDialog.java
git commit -m "feat: HelpDialog with usage instructions"
```

---

## Task 9: Implement ColorConfigDialog

**Objective:** Modal dialog to change background, text, and selection colors for the current session.

**Files:**
- Create: `src/main/java/com/llmcli/gui/ColorConfigDialog.java`

**Step 1: Write ColorConfigDialog.java**

```java
package com.llmcli.gui;

import javax.swing.*;
import java.awt.*;

public class ColorConfigDialog extends JDialog {
    private final MainWindow mainWindow;

    private Color bgColor = UIManager.getColor("Panel.background");
    private Color textColor = UIManager.getColor("Label.foreground");
    private Color selColor = UIManager.getColor("Table.selectionBackground");

    public ColorConfigDialog(JFrame parent, MainWindow mainWindow) {
        super(parent, "Color Configuration", true);
        this.mainWindow = mainWindow;
        initUI();
    }

    private void initUI() {
        setSize(400, 350);
        setResizable(false);
        setLocationRelativeTo(getParent());
        setLayout(new GridBagLayout());

        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(8, 8, 8, 8);
        gbc.anchor = gbc.WEST;

        // Background color
        gbc.gridx = 0; gbc.gridy = 0;
        add(new JLabel("Background:"), gbc);
        gbc.gridx = 1;
        JButton bgBtn = new ColorButton("Background", bgColor, c -> bgColor = c);
        add(bgBtn, gbc);

        // Text color
        gbc.gridx = 0; gbc.gridy = 1;
        add(new JLabel("Text:"), gbc);
        gbc.gridx = 1;
        JButton txtBtn = new ColorButton("Text", textColor, c -> textColor = c);
        add(txtBtn, gbc);

        // Selection color
        gbc.gridx = 0; gbc.gridy = 2;
        add(new JLabel("Selection:"), gbc);
        gbc.gridx = 1;
        JButton selBtn = new ColorButton("Selection", selColor, c -> selColor = c);
        add(selBtn, gbc);

        // Buttons
        gbc.gridx = 0; gbc.gridy = 3; gbc.gridwidth = 2;
        gbc.fill = gbc.NONE;
        gbc.anchor = gbc.CENTER;
        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));

        JButton applyBtn = new JButton("Apply");
        applyBtn.addActionListener(e -> applyColors());

        JButton resetBtn = new JButton("Reset");
        resetBtn.addActionListener(e -> {
            bgColor = UIManager.getColor("Panel.background");
            textColor = UIManager.getColor("Label.foreground");
            selColor = UIManager.getColor("Table.selectionBackground");
            bgBtn.setBackground(bgColor);
            txtBtn.setBackground(textColor);
            selBtn.setBackground(selColor);
        });

        JButton closeBtn = new JButton("Close");
        closeBtn.addActionListener(e -> dispose());

        btnPanel.add(applyBtn);
        btnPanel.add(resetBtn);
        btnPanel.add(closeBtn);
        add(btnPanel, gbc);
    }

    private void applyColors() {
        JFrame frame = mainWindow.getFrame();
        frame.getContentPane().setBackground(bgColor);

        JTable table = mainWindow.getTable();
        table.setBackground(bgColor);
        table.setForeground(textColor);
        table.setSelectionBackground(selColor);
        table.getTableHeader().repaint();

        SwingUtilities.updateComponentTreeUI(frame);
        frame.validate();
        frame.repaint();
    }

    // Inner class: button that shows its color and opens JColorChooser on click
    private static class ColorButton extends JButton {
        private final java.awt.event.ActionListener onSelect;

        ColorButton(String label, Color initial, java.awt.event.ActionListener onSelect) {
            super(label);
            setForeground(initial);
            setOpaque(true);
            setContentAreaFilled(false);
            this.onSelect = onSelect;
            addActionListener(e -> {
                Color chosen = JColorChooser.showDialog(ColorButton.this, "Choose Color", getForeground());
                if (chosen != null) {
                    setForeground(chosen);
                    onSelect.actionPerformed(e);
                }
            });
        }
    }
}
```

**Step 2: Add getTable() to MainWindow**

Modify `MainWindow.java` -- add this method:

```java
    public JTable getTable() { return table; }
```

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/gui/ColorConfigDialog.java
git add src/main/java/com/llmcli/gui/MainWindow.java
git commit -m "feat: ColorConfigDialog with Apply/Reset/Close"
```

---

## Task 10: Wire menu bar into MainWindow

**Objective:** Add the Tools menu with Add command, Help, and Color config items.

**Files:**
- Modify: `src/main/java/com/llmcli/gui/MainWindow.java`

**Step 1: Replace the menu bar initialization in `initUI()`**

Find the comment `// Menu bar` in `initUI()` and replace the two lines below it with:

```java
        // Menu bar
        menuBar = new JMenuBar();
        JMenu toolsMenu = new JMenu("Tools");

        JMenuItem addCmd = new JMenuItem("Add command...");
        addCmd.addActionListener(e -> {
            new AddCommandDialog(frame, store, this::refreshTable).setVisible(true);
        });

        JMenuItem helpItem = new JMenuItem("Help");
        helpItem.addActionListener(e -> new HelpDialog(frame).setVisible(true));

        JMenuItem colorItem = new JMenuItem("Color config");
        colorItem.addActionListener(e -> new ColorConfigDialog(frame, this).setVisible(true));

        toolsMenu.add(addCmd);
        toolsMenu.add(helpItem);
        toolsMenu.add(colorItem);
        menuBar.add(toolsMenu);
        frame.setJMenuBar(menuBar);
```

**Step 2: Compile**

```bash
mvn clean compile
```

Expected: BUILD SUCCESS.

**Step 3: Commit**

```bash
git add src/main/java/com/llmcli/gui/MainWindow.java
git commit -m "feat: wire Tools menu with Add, Help, Color config"
```

---

## Task 11: Create Main entry point

**Objective:** Application bootstrap -- set look-and-feel, create and show the main window.

**Files:**
- Create: `src/main/java/com/llmcli/Main.java`

**Step 1: Write Main.java**

```java
package com.llmcli;

import com.llmcli.gui.MainWindow;

import javax.swing.*;

public class Main {
    public static void main(String[] args) {
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception e) {
            try {
                UIManager.setLookAndFeel("javax.swing.plaf.metal.MetalLookAndFeel");
            } catch (Exception ex) {
                // fall through to default
            }
        }

        SwingUtilities.invokeLater(() -> {
            MainWindow mainWindow = new MainWindow();
            mainWindow.show();
        });
    }
}
```

**Step 2: Compile and package**

```bash
mvn clean package
```

Expected: BUILD SUCCESS, JAR at `target/llm-cli-tool-1.0.0.jar`.

**Step 3: Quick smoke test**

```bash
java -jar target/llm-cli-tool-1.0.0.jar &
sleep 2
pkill -f "llm-cli-tool"
```

Expected: app starts, shows empty table, exits cleanly.

**Step 4: Commit**

```bash
git add src/main/java/com/llmcli/Main.java
git commit -m "feat: Main entry point with system LAF and SwingUtilities.invokeLater"
```

---

## Task 12: Create launcher.sh

**Objective:** Bash script that checks for the JAR and runs it.

**Files:**
- Create: `launcher.sh`

**Step 1: Write launcher.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

JAR="target/llm-cli-tool-1.0.0.jar"

if [[ ! -f "$JAR" ]]; then
    echo "JAR not found at $JAR. Run 'mvn clean package' first." >&2
    exit 1
fi

exec java -jar "$JAR"
```

**Step 2: Make executable**

```bash
chmod +x launcher.sh
```

**Step 3: Verify**

```bash
./launcher.sh &
sleep 2
pkill -f "llm-cli-tool"
```

Expected: app starts and exits cleanly.

**Step 4: Commit**

```bash
git add launcher.sh
git commit -m "feat: bash launcher script with JAR existence check"
```

---

## Task 13: Final integration -- compile, run, and verify end-to-end

**Objective:** Full build, manual smoke test of all features, and final commit.

**Files:**
- No new files. Verify all existing ones.

**Step 1: Clean build**

```bash
mvn clean package -q
```

Expected: BUILD SUCCESS, no warnings.

**Step 2: Verify project tree**

```bash
find src -name "*.java" | sort
```

Expected output:

```
src/main/java/com/llmcli/Main.java
src/main/java/com/llmcli/gui/AddCommandDialog.java
src/main/java/com/llmcli/gui/ColorConfigDialog.java
src/main/java/com/llmcli/gui/EditPopup.java
src/main/java/com/llmcli/gui/HelpDialog.java
src/main/java/com/llmcli/gui/MainWindow.java
src/main/java/com/llmcli/model/Command.java
src/main/java/com/llmcli/storage/CommandStore.java
```

**Step 3: Verify JAR manifest**

```bash
unzip -p target/llm-cli-tool-1.0.0.jar META-INF/MANIFEST.MF | grep Main-Class
```

Expected: `Main-Class: com.llmcli.Main`

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete LLM CLI Tool implementation"
```

---

## Task Dependencies

```
Task 1 (Maven skeleton)
  └── Task 2 (Command model)
        └── Task 3 (CommandStore writer)
              └── Task 4 (CommandStore reader)
                    └── Task 5 (MainWindow)
                          ├── Task 6 (AddCommandDialog)
                          ├── Task 7 (EditPopup)
                          ├── Task 8 (HelpDialog)
                          ├── Task 9 (ColorConfigDialog)
                          └── Task 10 (Wire menu bar)
                                └── Task 11 (Main entry point)
                                      └── Task 12 (launcher.sh)
                                            └── Task 13 (Final integration)
```

Tasks 6-9 are independent of each other and could theoretically be built in parallel once Tasks 3-5 are done. Task 10 depends on all of them.
