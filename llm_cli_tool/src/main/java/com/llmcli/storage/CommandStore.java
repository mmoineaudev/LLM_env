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
    private static final Pattern NAME_PATTERN = Pattern.compile("^[-a-zA-Z0-9_.]+$");
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
}