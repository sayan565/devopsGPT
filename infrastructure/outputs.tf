output "api_gateway_url" { value = module.api_gateway.invoke_url }
output "api_key_id"      { value = module.api_gateway.api_key_id }
output "websocket_url"   { value = module.websocket.wss_url }