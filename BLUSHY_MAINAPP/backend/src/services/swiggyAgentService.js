import { env } from '../utils/env.js';
import { aiFetch } from '../utils/aiRequest.js';
import { createHttpError } from '../utils/httpError.js';

const INSTAMART_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_addresses',
      description: "Retrieve all saved delivery addresses for the authenticated Swiggy user. ALWAYS call this first to get the user's active addressId.",
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'your_go_to_items',
      description: 'Get frequently ordered SKUs for quick reorders at the specified address.',
      parameters: {
        type: 'object',
        properties: {
          addressId: { type: 'string', description: 'Address ID resolved from get_addresses' },
        },
        required: ['addressId'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_products',
      description: 'Search for grocery products available on Instamart at the specified address.',
      parameters: {
        type: 'object',
        properties: {
          addressId: { type: 'string', description: 'Address ID resolved from get_addresses' },
          query: { type: 'string', description: 'The search query (e.g. bananas, milk, bread)' },
        },
        required: ['addressId', 'query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_cart',
      description: 'Update the Instamart cart with items. Replaces the current cart. You must provide all items that should be in the cart.',
      parameters: {
        type: 'object',
        properties: {
          items: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                spinId: { type: 'string', description: 'The unique variant spinId from search_products' },
                quantity: { type: 'integer', description: 'The quantity to set for this item' },
              },
              required: ['spinId', 'quantity'],
            },
          },
        },
        required: ['items'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'clear_cart',
      description: 'Clear all items currently in the Instamart cart.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_cart',
      description: 'Get current Instamart cart details and billing breakdown.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'checkout',
      description: 'Place the order for the items in the current cart. Cash on Delivery (COD) is supported.',
      parameters: {
        type: 'object',
        properties: {
          paymentMethod: { type: 'string', enum: ['COD'], description: 'Payment method, defaults to COD' },
        },
        required: ['paymentMethod'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'track_order',
      description: 'Track the status of an active Instamart order.',
      parameters: {
        type: 'object',
        properties: {
          orderId: { type: 'string', description: 'The ID of the order to track' },
        },
        required: ['orderId'],
      },
    },
  },
];

async function callSwiggyMcpTool(toolName, args, swiggyToken) {
  try {
    const response = await fetch('https://mcp.swiggy.com/im', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        'Authorization': `Bearer ${swiggyToken}`,
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: Date.now(),
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args,
        },
      }),
    });

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error('SWIGGY_UNAUTHORIZED');
      }
      const errText = await response.text();
      throw new Error(`Swiggy MCP server responded with status ${response.status}: ${errText}`);
    }

    const payload = await response.json();
    if (payload.error) {
      throw new Error(payload.error.message || JSON.stringify(payload.error));
    }
    return payload.result;
  } catch (error) {
    console.error(`Error calling Swiggy MCP tool ${toolName}:`, error);
    throw error;
  }
}

export class SwiggyAgentService {
  static async runAgent({ messages, swiggyToken }) {
    if (!env.aiChatApiKey) {
      throw createHttpError(503, 'The AI provider key (GROK_API_KEY) is not configured on this server.');
    }

    if (!swiggyToken) {
      throw createHttpError(401, 'Swiggy authentication token is missing. Please log in first.');
    }

    let chatHistory = [
      {
        role: 'system',
        content: `You help users shop on Swiggy Instamart. Start by resolving the user's saved address using get_addresses. Offer your_go_to_items for quick reorders; use search_products for new queries. Always confirm the cart and total before checkout. COD-only in v1.
Common errors you should handle and explain to the user:
- Item out of stock at this address: suggest alternatives from search_products.
- Address not serviceable: Instamart doesn't deliver here; ask for another address or offer Food.
- Minimum order not met (cart under ₹99): prompt user to add items to meet the minimum.
- Cart expired / abandoned: rebuild the cart.`,
      },
      ...messages.map((m) => ({
        role: m.role,
        content: m.content,
        ...(m.tool_calls ? { tool_calls: m.tool_calls } : {}),
      })),
    ];

    let loopCount = 0;
    const maxLoops = 5;
    const toolExecutions = [];

    while (loopCount < maxLoops) {
      loopCount++;
      
      const response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
          'X-Title': 'Swiggy Instamart AI Copilot',
        },
        body: JSON.stringify({
          model: env.aiChatModel,
          messages: chatHistory,
          tools: INSTAMART_TOOLS,
          tool_choice: 'auto',
          max_tokens: 500,
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        throw createHttpError(response.status, `LLM error: ${errText}`);
      }

      const payload = await response.json();
      const choice = payload.choices?.[0];
      if (!choice) {
        throw createHttpError(502, 'LLM returned an empty response.');
      }

      const assistantMessage = choice.message;
      chatHistory.push(assistantMessage);

      if (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
        for (const toolCall of assistantMessage.tool_calls) {
          const { name, arguments: argsString } = toolCall.function;
          let args = {};
          try {
            args = typeof argsString === 'string' ? JSON.parse(argsString) : argsString;
          } catch (e) {
            console.error('Failed to parse tool call arguments:', e);
          }

          console.log(`Swiggy Agent calling tool: ${name} with args:`, args);
          
          let toolResult;
          try {
            toolResult = await callSwiggyMcpTool(name, args, swiggyToken);
            toolExecutions.push({
              tool: name,
              args,
              success: true,
              result: toolResult,
            });
          } catch (err) {
            toolResult = { error: err.message };
            toolExecutions.push({
              tool: name,
              args,
              success: false,
              error: err.message,
            });

            if (err.message === 'SWIGGY_UNAUTHORIZED') {
              throw createHttpError(401, 'Your Swiggy session has expired. Please log in again.');
            }
          }

          chatHistory.push({
            role: 'tool',
            tool_call_id: toolCall.id,
            name: name,
            content: JSON.stringify(toolResult),
          });
        }
        // Continue loop to let the LLM generate the response based on the tool results
      } else {
        // No tool calls, we are done
        return {
          message: assistantMessage.content,
          toolExecutions,
        };
      }
    }

    throw createHttpError(500, 'Tool invocation loop limit exceeded.');
  }
}
