const WebSocket = require("ws");
const express = require("express");
const axios = require("axios");

const app = express();
const httpPort = 3001;
const wsPort = 8765;

app.use(express.json());

const wss = new WebSocket.Server({ port: wsPort });
let swiftClients = new Set();

wss.on("connection", (ws) => {
    console.log("Swift app connected");
    swiftClients.add(ws);

    ws.on("message", async (message) => {
        console.log("Received from client:", message.toString());

        try {
            await axios.post("http://localhost:8000/set-latlon", JSON.parse(message.toString()));
            console.log("Successfully forwarded lat/lon to Flask.");
        } catch (err) {
            console.error("Error forwarding to Flask:", err.message);
        }
    });

    ws.on("close", () => {
        console.log("Swift app disconnected");
        swiftClients.delete(ws);
    });
});

app.get("/trigger", (req, res) => {
    console.log("Received request from Flask /verifytx");
    swiftClients.forEach((ws) => {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send("sendlatlon");
        }
    });

    res.json({ message: "WebSocket message sent" });
});

app.listen(httpPort, () => {
    console.log(`Node.js HTTP server running on port ${httpPort}`);
});

console.log(`WebSocket server running on port ${wsPort}`);
