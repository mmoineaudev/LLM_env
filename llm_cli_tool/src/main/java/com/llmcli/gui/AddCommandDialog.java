package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
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
        setSize(500, 400);
        setResizable(true);
        setLocationRelativeTo(getParent());

        JTextField nameField = new JTextField(30);
        JTextArea bodyArea = new JTextArea();
        bodyArea.setLineWrap(true);
        bodyArea.setWrapStyleWord(true);
        bodyArea.setBorder(new EmptyBorder(4, 4, 4, 4));
        JTextArea commentArea = new JTextArea();
        commentArea.setLineWrap(true);
        commentArea.setWrapStyleWord(true);
        commentArea.setBorder(new EmptyBorder(4, 4, 4, 4));

        JScrollPane bodyScroll = new JScrollPane(bodyArea);
        JScrollPane commentScroll = new JScrollPane(commentArea);

        JPanel btnPanel = makeButtonPanel(nameField, bodyArea, commentArea);

        // GridBagLayout: body and comment areas expand to fill available space
        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(4, 8, 4, 8);
        gbc.fill = GridBagConstraints.HORIZONTAL;

        // Row 0: Name
        gbc.gridx = 0; gbc.gridy = 0;
        gbc.weightx = 0; gbc.weighty = 0;
        add(new JLabel("Name:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        add(nameField, gbc);

        // Row 1: Body label
        gbc.gridx = 0; gbc.gridy = 1;
        gbc.weightx = 0; gbc.weighty = 0;
        add(new JLabel("Body:"), gbc);

        // Row 2: Body area - expands
        gbc.gridx = 0; gbc.gridy = 2;
        gbc.gridwidth = 2;
        gbc.weightx = 1; gbc.weighty = 1;
        gbc.fill = GridBagConstraints.BOTH;
        add(bodyScroll, gbc);

        // Row 3: Comment label
        gbc.gridx = 0; gbc.gridy = 3;
        gbc.gridwidth = 1;
        gbc.weightx = 0; gbc.weighty = 0;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        add(new JLabel("Comment:"), gbc);

        // Row 4: Comment area - expands
        gbc.gridx = 0; gbc.gridy = 4;
        gbc.gridwidth = 2;
        gbc.weightx = 1; gbc.weighty = 1;
        gbc.fill = GridBagConstraints.BOTH;
        add(commentScroll, gbc);

        // Row 5: Buttons - fixed height
        gbc.gridx = 0; gbc.gridy = 5;
        gbc.gridwidth = 2;
        gbc.weightx = 0; gbc.weighty = 0;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        add(btnPanel, gbc);
    }

    private JPanel makeButtonPanel(JTextField nameField, JTextArea bodyArea, JTextArea commentArea) {
        JPanel panel = new JPanel(new FlowLayout(FlowLayout.RIGHT, 8, 4));

        JButton saveBtn = new JButton("Save");
        saveBtn.addActionListener(e -> {
            String name = nameField.getText().trim();
            if (name.isEmpty() || !store.isValidName(name)) {
                JOptionPane.showMessageDialog(AddCommandDialog.this,
                        "Invalid name. Use only letters, digits, hyphens, underscores, and dots.",
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

        JButton cancelBtn = new JButton("Cancel");
        cancelBtn.addActionListener(e -> dispose());

        panel.add(saveBtn);
        panel.add(cancelBtn);
        return panel;
    }
}
