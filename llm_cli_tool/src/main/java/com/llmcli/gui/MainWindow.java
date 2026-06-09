package com.llmcli.gui;

import com.llmcli.model.Command;
import com.llmcli.storage.CommandStore;

import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import javax.swing.table.TableColumn;
import java.awt.*;
import java.util.ArrayList;
import java.util.List;

public class MainWindow {
    private JFrame frame;
    private JTable table;
    private DefaultTableModel tableModel;
    private final CommandStore store;
    private SystemInfoPanel systemInfoPanel;

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

        // System info panel at top
        systemInfoPanel = new SystemInfoPanel();
        frame.add(systemInfoPanel, BorderLayout.NORTH);

        // Table model
        tableModel = new DefaultTableModel(new Object[]{"Name", "Comment"}, 0) {
            @Override
            public boolean isCellEditable(int row, int col) {
                return false;
            }
        };
        table = new JTable(tableModel);
        table.getColumnModel().getColumn(0).setPreferredWidth(200);

        // Add Action column for Run buttons
        TableColumn actionColumn = new TableColumn();
        actionColumn.setHeaderValue("Action");
        actionColumn.setPreferredWidth(60);
        actionColumn.setMaxWidth(80);
        ButtonRenderer buttonRenderer = new ButtonRenderer();
        actionColumn.setCellRenderer(buttonRenderer);
        table.getColumnModel().addColumn(actionColumn);

        // Add a MouseListener to the table for Name/Comment column clicks and Action column run button
        table.addMouseListener(new java.awt.event.MouseAdapter() {
            @Override
            public void mouseClicked(java.awt.event.MouseEvent e) {
                int row = table.rowAtPoint(e.getPoint());
                if (row < 0) {
                    System.err.println("[DEBUG] mouseClicked: row < 0");
                    return;
                }

                int col = table.columnAtPoint(e.getPoint());
                Rectangle cellRect = table.getCellRect(row, col, false);
                System.err.println("[DEBUG] mouseClicked: row=" + row + " col=" + col + " point=(" + e.getX() + "," + e.getY() + ") cellRect=(" + cellRect.x + "," + cellRect.y + " " + cellRect.width + "x" + cellRect.height + ")");

                // Action column: check for run button click on rightmost area of the cell
                if (col == 2) {
                    int btnWidth = 50; // approximate button width
                    if (e.getX() >= cellRect.x + cellRect.width - btnWidth) {
                        System.err.println("[DEBUG] mouseClicked: Action column run button click");
                        runCommand(row);
                    }
                    return; // don't fall through to other column handlers
                }

                // Name/Comment columns — show edit popup
                if (col == 0 || col == 1) {
                    System.err.println("[DEBUG] mouseClicked: Name/Comment column click");
                    String name = (String) tableModel.getValueAt(row, 0);
                    List<Command> commands = store.loadCommands();
                    Command cmd = commands.stream()
                            .filter(c -> c.getName().equals(name))
                            .findFirst().orElse(null);
                    if (cmd == null) {
                        System.err.println("[DEBUG] mouseClicked: command not found for name=" + name);
                        return;
                    }

                    if (col == 0) {
                        System.err.println("[DEBUG] mouseClicked: showing BODY popup for " + name);
                        new EditPopup(frame, cmd, EditPopup.Mode.BODY, MainWindow.this::refreshTable);
                    } else if (col == 1) {
                        System.err.println("[DEBUG] mouseClicked: showing COMMENT popup for " + name);
                        new EditPopup(frame, cmd, EditPopup.Mode.COMMENT, MainWindow.this::refreshTable);
                    }
                }
            }
        });

        // Add table in a scroll pane to the center of the frame
        JScrollPane scrollPane = new JScrollPane(table);
        frame.add(scrollPane, BorderLayout.CENTER);

        // Menu bar
        JMenuBar menuBar = new JMenuBar();
        JMenu toolsMenu = new JMenu("Tools");

        JMenuItem addCmd = new JMenuItem("Add command...");
        addCmd.addActionListener(e -> {
            new AddCommandDialog(frame, store, this::refreshTable).setVisible(true);
        });

        JMenuItem helpItem = new JMenuItem("Help");
        helpItem.addActionListener(e -> new HelpDialog(frame).setVisible(true));

        JMenuItem colorItem = new JMenuItem("Color config");
        colorItem.addActionListener(e -> new ColorConfigDialog(frame, MainWindow.this).setVisible(true));

        toolsMenu.add(addCmd);
        toolsMenu.add(helpItem);
        toolsMenu.add(colorItem);
        menuBar.add(toolsMenu);
        frame.setJMenuBar(menuBar);
    }

    private void runCommand(int row) {
        String name = (String) tableModel.getValueAt(row, 0);
        List<Command> commands = store.loadCommands();
        Command cmd = commands.stream()
                .filter(c -> c.getName().equals(name))
                .findFirst().orElse(null);
        if (cmd == null || cmd.getBody().isEmpty()) {
            JOptionPane.showMessageDialog(frame,
                    "No command body to execute.",
                    "Nothing to run", JOptionPane.INFORMATION_MESSAGE);
            return;
        }

        TerminalRunner.runInTerminal(cmd.getBody());
    }

    public void refreshTable() {
        tableModel.setRowCount(0);
        List<Command> commands = new ArrayList<>(store.loadCommands());
        commands.sort((a, b) -> a.getName().compareToIgnoreCase(b.getName()));
        for (Command cmd : commands) {
            tableModel.addRow(new Object[]{cmd.getName(), cmd.getComment()});
        }
    }

    public JFrame getFrame() { return frame; }
    public JTable getTable() { return table; }

    public void show() {
        frame.setSize(frame.getPreferredSize());
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);
    }
}
