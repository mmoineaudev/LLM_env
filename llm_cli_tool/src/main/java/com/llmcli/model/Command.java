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
