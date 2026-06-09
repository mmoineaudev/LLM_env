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

        add(new JScrollPane(textArea), BorderLayout.CENTER);

        JPanel btnPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));
        JButton okBtn = new JButton("OK");
        okBtn.addActionListener(e -> dispose());
        btnPanel.add(okBtn);
        add(btnPanel, BorderLayout.SOUTH);
    }
}
