package com.llmcli.gui;

import javax.swing.*;
import javax.swing.border.TitledBorder;
import java.awt.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Displays system resource usage: CPU frequency, RAM %, VRAM % as styled progress bars.
 * Updates every 5 seconds via SwingTimer on the EDT.
 */
public class SystemInfoPanel extends JPanel {
    private final JProgressBar cpuFreqBar;
    private final JLabel cpuFreqLabel;
    private final JProgressBar ramBar;
    private final JLabel ramLabel;
    private final JProgressBar vramBar;
    private final JLabel vramLabel;

    private final Timer updateTimer;

    // Color thresholds: green <70%, orange 70-92%, red >92%
    private static final int GREEN = 0;
    private static final int ORANGE = 70;
    private static final int RED = 92;

    public SystemInfoPanel() {
        setLayout(new GridBagLayout());
        setBorder(BorderFactory.createTitledBorder(
                BorderFactory.createMatteBorder(1, 1, 1, 1, new Color(80, 80, 80)),
                "System", TitledBorder.CENTER, TitledBorder.TOP));

        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(2, 4, 2, 4);
        gbc.fill = GridBagConstraints.HORIZONTAL;

        // CPU Frequency bar
        cpuFreqBar = new JProgressBar(0, 100);
        cpuFreqBar.setPreferredSize(new Dimension(250, 16));
        cpuFreqBar.setMinimumSize(cpuFreqBar.getPreferredSize());
        setBarColor(cpuFreqBar, GREEN);
        cpuFreqLabel = new JLabel("Loading CPU...");
        gbc.gridx = 0; gbc.gridy = 0;
        add(new JLabel("CPU:  "), gbc);
        gbc.gridx = 1;
        add(cpuFreqBar, gbc);
        gbc.gridx = 2;
        add(cpuFreqLabel, gbc);

        // RAM usage bar
        ramBar = new JProgressBar(0, 100);
        ramBar.setPreferredSize(new Dimension(250, 16));
        ramBar.setMinimumSize(ramBar.getPreferredSize());
        setBarColor(ramBar, GREEN);
        ramLabel = new JLabel("Loading RAM...");
        gbc.gridx = 0; gbc.gridy = 1;
        add(new JLabel("RAM:  "), gbc);
        gbc.gridx = 1;
        add(ramBar, gbc);
        gbc.gridx = 2;
        add(ramLabel, gbc);

        // VRAM usage bar
        vramBar = new JProgressBar(0, 100);
        vramBar.setPreferredSize(new Dimension(250, 16));
        vramBar.setMinimumSize(vramBar.getPreferredSize());
        setBarColor(vramBar, GREEN);
        vramLabel = new JLabel("Loading VRAM...");
        gbc.gridx = 0; gbc.gridy = 2;
        add(new JLabel("VRAM: "), gbc);
        gbc.gridx = 1;
        add(vramBar, gbc);
        gbc.gridx = 2;
        add(vramLabel, gbc);

        // Update every 5 seconds
        updateTimer = new Timer(5000, e -> updateValues());
        updateTimer.start();

        // Initial read
        SwingUtilities.invokeLater(this::updateValues);
    }

    private void setBarColor(JProgressBar bar, int level) {
        if (level <= GREEN) {
            bar.setForeground(new Color(46, 125, 50));    // green
        } else if (level <= ORANGE) {
            bar.setForeground(new Color(255, 160, 0));     // orange
        } else {
            bar.setForeground(new Color(211, 47, 47));     // red
        }
    }

    private void updateValues() {
        readCPUFrequency();
        readRAMUsage();
        readVRAMUsage();
    }

    private void readCPUFrequency() {
        List<Long> frequencies = new ArrayList<>();
        for (int i = 0; i < Runtime.getRuntime().availableProcessors(); i++) {
            try {
                String line = Files.readString(Path.of(
                        "/sys/devices/system/cpu/cpu" + i,
                        "/cpufreq/scaling_cur_freq")).trim();
                frequencies.add(Long.parseLong(line));
            } catch (Exception e) {
                // Try alternative path
                try {
                    String line = Files.readString(Path.of(
                            "/sys/devices/system/cpu/cpu" + i,
                            "/cpufreq/cpuinfo_avg_freq")).trim();
                    frequencies.add(Long.parseLong(line));
                } catch (Exception e2) {
                    // Skip this CPU
                }
            }
        }

        if (frequencies.isEmpty()) {
            SwingUtilities.invokeLater(() -> cpuFreqLabel.setText("N/A"));
            return;
        }

        double avgFreqKHzD = frequencies.stream()
                .mapToLong(Long::longValue).average().orElse(0);
        long avgFreqKHz = (long) avgFreqKHzD;
        final long maxFreqKHz = getCPUinfoMaxFreq();

        // Scale progress bar: 0-100% of max frequency
        final int percent = maxFreqKHz > 0 ?
                Math.max(0, Math.min(100, (int) Math.round(avgFreqKHz * 100.0 / maxFreqKHz))) : 0;

        final long avgFreqMHz = avgFreqKHz / 1000;
        SwingUtilities.invokeLater(() -> {
            cpuFreqBar.setValue(percent);
            setBarColor(cpuFreqBar, getUsageLevel(percent));
            cpuFreqLabel.setText(String.format("%d MHz", avgFreqMHz));
        });
    }

    private long getCPUinfoMaxFreq() {
        try {
            String line = Files.readString(
                    Path.of("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")).trim();
            return Long.parseLong(line);
        } catch (Exception e) {
            // Try scaling_max_freq
            String line;
            try {
                line = Files.readString(
                        Path.of("/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq")).trim();
            } catch (Exception ex2) {
                return 0; // Default to 0 if we can't find max freq
            }
            return Long.parseLong(line);
        }
    }

    private void readRAMUsage() {
        final String content;
        try {
            content = Files.readString(Path.of("/proc/meminfo"));
        } catch (IOException e) {
            SwingUtilities.invokeLater(() -> ramLabel.setText("Error"));
            return;
        }

        long totalKb = 0, availableKb = 0;
        for (String line : content.split("\\n")) {
            if (line.startsWith("MemTotal:")) {
                try {
                    totalKb = Long.parseLong(line.replace("MemTotal:", "").trim().split("\\s+")[0]);
                } catch (NumberFormatException e2) {
                    SwingUtilities.invokeLater(() -> ramLabel.setText("Error"));
                    return;
                }
            } else if (line.startsWith("MemAvailable:")) {
                try {
                    availableKb = Long.parseLong(line.replace("MemAvailable:", "").trim().split("\\s+")[0]);
                } catch (NumberFormatException e2) {
                    SwingUtilities.invokeLater(() -> ramLabel.setText("Error"));
                    return;
                }
            }
        }

        final int percent = totalKb > 0 ?
                Math.max(0, Math.min(100, (int) Math.round((1.0 - availableKb * 1.0 / totalKb) * 100))) : 0;
        final long usedMB = (totalKb - availableKb) / 1024;

        SwingUtilities.invokeLater(() -> {
            ramBar.setValue(percent);
            setBarColor(ramBar, getUsageLevel(percent));
            ramLabel.setText(String.format("%d%% (%d MB)", percent, usedMB));
        });
    }

    private void readVRAMUsage() {
        new Thread(() -> {
            try {
                ProcessBuilder pb = new ProcessBuilder("sh", "-c",
                        "nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits");
                Process proc = pb.start();

                StringBuilder sb = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(
                        new InputStreamReader(proc.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        sb.append(line.trim());
                    }
                }

                if (!proc.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    proc.destroyForcibly();
                    SwingUtilities.invokeLater(() -> vramLabel.setText("N/A"));
                    return;
                }

                int exitCode = proc.exitValue();
                if (exitCode != 0 || sb.toString().isEmpty()) {
                    SwingUtilities.invokeLater(() -> vramLabel.setText("N/A"));
                    return;
                }

                final String output = sb.toString();
                final String[] parts = output.split(",");
                final long usedMiB = Long.parseLong(parts[0].trim());
                final long totalMiB = Long.parseLong(parts[1].trim());

                final int percent = totalMiB > 0 ?
                        Math.max(0, Math.min(100, (int) Math.round(usedMiB * 100.0 / totalMiB))) : 0;

                SwingUtilities.invokeLater(() -> {
                    vramBar.setValue(percent);
                    setBarColor(vramBar, getUsageLevel(percent));
                    vramLabel.setText(String.format("%d%% (%d MB)", percent, usedMiB));
                });
            } catch (Exception e) {
                SwingUtilities.invokeLater(() -> vramLabel.setText("N/A"));
            }
        }).start();
    }

    private int getUsageLevel(int percent) {
        if (percent <= GREEN) return GREEN;
        else if (percent <= ORANGE) return ORANGE;
        else return RED;
    }

    @Override
    public Dimension getMaximumSize() {
        return new Dimension(Integer.MAX_VALUE, 80);
    }

    @Override
    public void setVisible(boolean visible) {
        if (visible) {
            updateTimer.start();
        } else {
            updateTimer.stop();
        }
        super.setVisible(visible);
    }
}
