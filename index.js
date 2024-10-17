import express from "express"; // Import Express
import * as dasha from "@dasha.ai/sdk"; // Import the Dasha SDK
import cors from "cors"; // Import CORS
import dotenv from "dotenv";
dotenv.config(); // Load environment variables from .env file

const app = express();
app.use(express.json()); // Middleware to parse JSON bodies
app.use(cors()); // Enable CORS for all routes

// Deploy the Dasha application
let dashaApp;
const initDasha = async () => {
  dashaApp = await dasha.deploy("./app");
  await dashaApp.start({ concurrency: 1 }); // Start the app with a concurrency of 1 (one conversation at a time)
};

initDasha().catch((e) => console.log("Error initializing Dasha:", e));

app.get("/", (req, res) => {
  res.send("Server is running and ready to accept requests.");
});

// Define an endpoint to initiate a call
app.post("/call", async (req, res) => {
  const { phoneNumber, name } = req.body; // Extract phone number and name from the request body

  if (!phoneNumber || !name) {
    return res
      .status(400)
      .json({ error: "Phone number and name are required." });
  }

  try {
    // Create a new conversation with the specified endpoint
    const conv = dashaApp.createConversation({
      endpoint: phoneNumber,
      name: name,
      openAiApiKey: process.env.OPENAI_API_KEY,
    });

    const result = await conv.execute(); // Execute the conversation

    // Send the result as the response
    res.json({ result: result.output });
  } catch (e) {
    console.log("Error during call execution:", e);
    res.status(500).json({ error: "Failed to make the call." });
  }
});

// Stop the Dasha app when the server is closed
const gracefulShutdown = async () => {
  if (dashaApp) {
    await dashaApp.stop();
    dashaApp.dispose();
  }
  process.exit();
};

process.on("SIGINT", gracefulShutdown);
process.on("SIGTERM", gracefulShutdown);

// Start the Express server
const PORT = 5001;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
