package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;

public class EditPopup extends JFrame {
    public enum Mode { BODY, COMMENT }

    private final Command cmd;
    private final Mode mode;
    private final CommandStore store;
    private final Runnable onSaved;
    private final JTextArea textArea;

    public EditPopup(JFrame parent, Command cmd, Mode mode, Runnable onSaved) {
        this.cmd = cmd;
        this.mode = mode;
        this.store = new CommandStore();
        this.onSaved = onSaved;

        setTitle(cmd.getName() + (mode == Mode.BODY ? " -- Body" : " -- Comment"));

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(600, 400);
        setLocationRelativeTo(parent);

        textArea = new JTextArea(
                mode == Mode.BODY ? cmd.getBody() : cmd.getComment());
        textArea.setLineWrap(true);
        textArea.setWrapStyleWord(true);
        textArea.setBorder(new EmptyBorder(4, 4, 4, 4));

        JScrollPane scrollPane = new JScrollPane(textArea);

        JPanel btnPanel = makeButtonPanel();

        // GridBag: text area gets all vertical space, buttons compact at bottom
        setLayout(new GridBagLayout());

        GridBagConstraints gbc = new GridBagConstraints();
        gbc.fill = GridBagConstraints.BOTH;

        // Row 0: scroll pane expands
        gbc.gridx = 0; gbc.gridy = 0;
        gbc.weightx = 1.0; gbc.weighty = 1.0;
        gbc.insets = new Insets(4, 4, 0, 4);
        add(scrollPane, gbc);

        // Row 1: buttons at bottom, fixed height
        gbc.gridy = 1;
        gbc.weighty = 0.0;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.insets = new Insets(2, 4, 4, 4);
        add(btnPanel, gbc);

        setVisible(true);
    }

    private JPanel makeButtonPanel() {
        JPanel panel = new JPanel(new FlowLayout(FlowLayout.RIGHT, 8, 4));

        JButton saveBtn = new JButton("Save");
        saveBtn.addActionListener(e -> {
            if (mode == Mode.BODY) cmd.setBody(textArea.getText());
            else cmd.setComment(textArea.getText());
            store.saveCommand(cmd);
            onSaved.run();
            dispose();
        });

        JButton closeBtn = new JButton("Close");
        closeBtn.addActionListener(e -> dispose());

        panel.add(saveBtn);
        panel.add(closeBtn);
        return panel;
    }
}
