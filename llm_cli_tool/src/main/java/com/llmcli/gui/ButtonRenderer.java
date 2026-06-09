package com.llmcli.gui;

import javax.swing.*;
import java.awt.*;

/**
 * Renders the Action column — shows a small triangle icon using a JLabel.
 * JLabel doesn't consume mouse events, so the JTable's MouseListener
 * can handle clicks via position-based detection.
 * Uses a dark color for the icon so it's always visible regardless of selection state.
 */
public class ButtonRenderer extends JLabel implements javax.swing.table.TableCellRenderer {
    private static final Icon RUN_ICON = new RunIcon();

    public ButtonRenderer() {
        setHorizontalAlignment(JLabel.CENTER);
        setIcon(RUN_ICON);
    }

    @Override
    public Component getTableCellRendererComponent(JTable table, Object value,
            boolean isSelected, boolean hasFocus, int row, int column) {
        // Always use a dark color for the icon so it's visible in both selected and unselected states
        if (isSelected) {
            setForeground(UIManager.getColor("Table.selectionForeground"));
            setBackground(UIManager.getColor("Table.selectionBackground"));
        } else {
            setForeground(new Color(30, 30, 30));  // dark gray/black - always visible
            setBackground(UIManager.getColor("Table.background"));
        }
        setText(null);
        setIcon(RUN_ICON);
        return this;
    }

    private static class RunIcon implements Icon {
        @Override
        public int getIconWidth()  { return 16; }
        @Override
        public int getIconHeight() { return 16; }

        @Override
        public void paintIcon(Component c, Graphics g, int x, int y) {
            Graphics2D g2d = (Graphics2D) g.create();
            g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            // Draw a right-pointing triangle (run/play symbol)
            int[] px = { x + 4, x + 16, x + 4, x + 4 };
            int[] py = { y + 1,  y + 8,  y + 15, y + 1 };
            g2d.setColor(c.getForeground());
            g2d.fillPolygon(px, py, px.length);
            g2d.dispose();
        }
    }
}
