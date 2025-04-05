import { execSync } from "child_process"; // Import execSync
// Use the local compiled SDK with enhanced logging
import { Client } from "./typescript-sdk/dist/esm/client/index.js";
import { SSEClientTransport } from "./typescript-sdk/dist/esm/client/sse.js";

// --- Configuration ---
// Read port from environment variable set by the Mix task, default to 4000
const port = process.env.MCP_SERVER_PORT ? parseInt(process.env.MCP_SERVER_PORT, 10) : 4000;
const serverUrl = `http://localhost:${port}/sse`; // Construct URL dynamically
const clientInfo = { name: "mcp-test-client", version: "0.0.1" };
// ---

async function runTest() {
	console.log(`\nAttempting full MCP connection to ${serverUrl} via SSE...`);

	// Use default transport options (including fetch wrapper)
	const transport = new SSEClientTransport(new URL(serverUrl));
	// Use our local client instance
	const client = new Client(clientInfo, { capabilities: {} });

	transport.onmessage = (message) => {
		console.log("[Test] Transport Message:", message);
	};

	transport.onerror = (error) => {
		console.error("[Test] Transport Error:", error);
	};

	transport.onclose = () => {
		console.log("[Test] Transport Closed");
	};

	try {
		// Use the standard client.connect() again
		console.log("[Test] Initiating client.connect()...");
		await client.connect(transport); // This should now work with the server fix
		console.log("[Test] ✅ client.connect() successful!");
		console.log("[Test] Server Info:", client.getServerVersion());
		console.log("[Test] Server Capabilities:", client.getServerCapabilities());

		try {
			console.log("[Test] Attempting client.listTools() with 120s timeout...");
			const toolsResult = await client.listTools(undefined, { timeout: 120000 }); // Increase timeout for debugging
			console.log("[Test] ✅ client.listTools() successful!");
			console.log("[Test] Tools:", JSON.stringify(toolsResult.tools, null, 2));

			if (toolsResult.tools && toolsResult.tools.length > 0) {
				const echoTool = toolsResult.tools.find(tool => tool.name === 'echo');
				if (echoTool) {
					console.log("[Test] Attempting to call echo tool...");
					const callResult = await client.callTool({
						name: "echo",
						arguments: { message: "Hello from TypeScript client!" }
					});
					console.log("[Test] ✅ Tool call successful!");
					console.log("[Test] Result:", JSON.stringify(callResult, null, 2));
				}
			}
		} catch (listToolsError) {
			console.error("[Test] ❌ Error during client.listTools():", listToolsError);
		}

	} catch (connectError) {
		console.error("[Test] ❌ Error during client.connect():", connectError);
		// Execute logs command on error
		try {
			console.log("\n--- Fetching server logs ---");
			const logs = execSync("cd ../apps/graph_os_protocol && mix protocol.server logs --tail 100", { encoding: 'utf8', stdio: 'pipe' });
			console.log(logs);
			console.log("--------------------------\n");
		} catch (logError) {
			console.error("[Test] ❌ Failed to fetch server logs:", logError);
		}
		process.exit(1); // Exit with error code if connect fails
	} finally {
		console.log("[Test] Closing client connection...");
		await client.close();
		console.log("[Test] Client connection closed.");
	}
}

runTest().catch(err => {
	console.error("[Test] Unhandled error during test run:", err);
	process.exit(1);
});
