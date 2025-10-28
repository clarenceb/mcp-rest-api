# Demo for exposing MCP Servers from API Management and LLM Logging capabilities

## Set up APIM REST API and expose as a MCP Server

- Create a REST API from the public Star Wars API: [https://swapi.dev/api/](https://swapi.dev/api/)
- Create a MCP Server in API Management from that REST API - choose "Expose an API as an MCP Server"
- Setup a subscription key to access the api or product that contains the api.

## Set up passthrough for existing MCP Server

- Choose an MCP server from https://mcp.azure.com/
- Example, Microsoft Learn MCP Server, which is unauthenticated: [https://mcp.azure.com/detail/msdocs-mcp-server](https://mcp.azure.com/detail/msdocs-mcp-server)
- Add the MCP Server in APIM - choose "Expose an existing MCP Server"

## VSCode MCP configuration

Confiure the `.vscode/mcp.json` file like so:

```json
{
    "inputs": [
    {
      "type": "promptString",
      "id": "api-key",
      "description": "APIM Subscription Key for MCP Demos",
      "password": true
    }
    ],
    "servers": {
        "star-wars-mcp-server": {
            "url": "https://<your-apim-instance>.azure-api.net/star-wars-movie-api-mcp-server/mcp",
            "headers": {
                "Ocp-Apim-Subscription-Key": "${input:api-key}"
            },
            "type": "http"
        },
        "mslearn-mcp-server": {
            "url": "https://<your-apim-instance>.azure-api.net/mslearn/api/mcp",
            "type": "http"
        }
    }
}
```

## Test out the REST API as an MCP Server

Set GitHub Copilot to `Agent` mode.

Ask some questions:

- Tell me about the Star Wars movie, A New Hope
- Create a table of all the Star Wars movies with the columns: Title, Release Date, Episode, and 3 keywords that summarise the movie (from the opening crawl).
- sort the moviers by year (asc)
- sort the movies by episode (roman numerals) asc
- Open the file [Placeholder.md](Placeholder.md) and then type in the Copilot Chat: Insert the last table in my open file

## Test out the MCP passthrough MCP Server

Set GitHub Copilot to `Agent` mode.

Ask some questions:

- How to create an Azure storage account using az cli?
- what's the bicep code for container apps workload profile setup?

## LLM Logging

Import an Azure OpenAI model from AI Foundry in Azure API Management.

If you enable [APIM LLM Logging](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-llm-logs), then you can check the LLM logs in the APIM Monitoring / Logs blade:

Run some chat completions using [ai-gateway.http](ai-gateway.http).

Check logs:

```sh
ApiManagementGatewayLogs
| where OperationId contains "ChatCompletions"
| order by TimeGenerated desc

ApiManagementGatewayLlmLog
| order by TimeGenerated desc, SequenceNumber asc
```

## Help GitHub Copilot choose the right MCP tools

See: [.github/copilot-instructions.md](.github/copilot-instructions.md)
