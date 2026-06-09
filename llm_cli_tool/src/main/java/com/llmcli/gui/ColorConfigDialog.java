package com.llmcli.gui;

import javax.swing.*;
import java.awt.*;

public class ColorConfigDialog extends JDialog {
    private final MainWindow mainWindow;

    private Color bgColor = UIManager.getColor("Panel.background");
    private Color textColor = UIManager.getColor("Label.foreground");
    private Color selColor = UIManager.getColor("Table.selectionBackground");

    private ColorButton bgBtn, txtBtn, selBtn;

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
        gbc.anchor = GridBagConstraints.WEST;

        gbc.gridx = 0;
        gbc.gridy = 0;
        add(new JLabel("Background:"), gbc);
        gbc.gridx = 1;
        bgBtn = new ColorButton("Background", bgColor, c -> bgColor = c);
        add(bgBtn, gbc);

        gbc.gridx = 0;
        gbc.gridy = 1;
        add(new JLabel("Text:"), gbc);
        gbc.gridx = 1;
        txtBtn = new ColorButton("Text", textColor, c -> textColor = c);
        add(txtBtn, gbc);

        gbc.gridx = 0;
        gbc.gridy = 2;
        add(new JLabel("Selection:"), gbc);
        gbc.gridx = 1;
        selBtn = new ColorButton("Selection", selColor, c -> selColor = c);
        add(selBtn, gbc);

        gbc.gridx = 0;
        gbc.gridy = 3;
        gbc.gridwidth = 2;
        gbc.fill = GridBagConstraints.NONE;
        gbc.anchor = GridBagConstraints.CENTER;
        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));

        JButton applyBtn = new JButton("Apply");
        applyBtn.addActionListener(e -> applyColors());

        JButton resetBtn = new JButton("Reset");
        resetBtn.addActionListener(e -> {
            bgColor = UIManager.getColor("Panel.background");
            textColor = UIManager.getColor("Label.foreground");
            selColor = UIManager.getColor("Table.selectionBackground");
            bgBtn.setColor(bgColor);
            txtBtn.setColor(textColor);
            selBtn.setColor(selColor);
            applyColors();
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
        table.repaint();

        frame.validate();
        frame.repaint();
    }

    private static class ColorButton extends JButton {
        private final java.util.function.Consumer<Color> onSelect;

        ColorButton(String label, Color initial, java.util.function.Consumer<Color> onSelect) {
            super(label);
            setBackground(initial);
            setOpaque(true);
            setContentAreaFilled(true);
            this.onSelect = onSelect;
            addActionListener(e -> {
                Color chosen = JColorChooser.showDialog(ColorButton.this, "Choose Color", getBackground());
                if (chosen != null) {
                    setColor(chosen);
                    onSelect.accept(chosen);
                }
            });
        }

        void setColor(Color c) {
            setBackground(c);
        }
    }
}
