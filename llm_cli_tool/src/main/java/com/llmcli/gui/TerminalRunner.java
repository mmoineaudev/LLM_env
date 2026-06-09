package com.llmcli.gui;

import java.io.IOException;

/**
 * Utility for launching commands in a Linux terminal window.
 */
public class TerminalRunner {

    /**
     * Launch the command in a new Linux terminal window.
     * The terminal remains open after the command finishes (shows "Press enter..." prompt).
     */
    public static void runInTerminal(String command) {
        if (command == null || command.trim().isEmpty()) {
            return;
        }

        // gnome-terminal, xfce4-terminal, konsole use -- before the command
        for (String terminal : new String[]{ "gnome-terminal", "xfce4-terminal", "konsole" }) {
            try {
                ProcessBuilder pb = new ProcessBuilder(terminal, "--", "bash", "-c",
                        command + " && read -p 'Press enter to close...'");
                pb.start();
                return;
            } catch (IOException ignored) {
                continue;
            }
        }

        // xterm, urxvt use -e before the command
        for (String terminal : new String[]{ "xterm", "urxvt" }) {
            try {
                ProcessBuilder pb = new ProcessBuilder(terminal, "-e", "/bin/sh",
                        "-c", command + " && read -p 'Press enter to close...'");
                pb.start();
                return;
            } catch (IOException ignored) {
                continue;
            }
        }
    }
}
