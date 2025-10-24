# Demo for expose REST API as MCP Server from API Management and LLM Logging

## Set up APIM REST API and MCP Server

Create a REST API from the public Star Wars API: https://swapi.dev/api/

Create a MCP Server in API Management from that REST API.

Setup a subscription key to access the api.

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
            "url": "https://<your-apim-instance>.azure-api.net/swapi-mcp/sse",
            "headers": {
                "Ocp-Apim-Subscription-Key": "${input:api-key}"
            }
        }
    }
}
```

## Test out the REST API as an MCP Server

Set GitHub Copilot to `Agent` mode.

Ask some questions:

* Tell me about the Star Wars movie, A New Hope
* Create a table of all the Star Wars movies with the columns: Title, Release Date, Episode, and 3 keywords that summarise the movie (from the opening crawl).
* sort the moviers by year (asc)
* sort the movies by episode (roman numerals) asc

* Open the file [Placehgolder.md](Placeholder.md) and then type in the Copilot Chat: Insert the last table in my open file

## LLM Logging

```sh
ApiManagementGatewayLogs
| where OperationId contains "ChatCompletions"
| order by TimeGenerated desc

ApiManagementGatewayLlmLog
| order by TimeGenerated desc, SequenceNumber asc
```
