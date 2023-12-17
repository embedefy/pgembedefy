// pgembedefy
// For the full copyright and license information, please view the LICENSE.txt file.

#include <string.h>
#include <json-c/json.h>
#include "api.h"
#include "strings.h"

// parse_v1_api_response parses the response body from a v1 API request.
V1APIResponseBody parse_v1_api_response(const char *json_str)
{
  V1APIResponseBody result = {.data = NULL, .error = NULL, .message = NULL};
  struct json_object *parsed_json, *inputs_array, *first_input_obj, *data_json, *error_json, *message_json;

  // Parse the JSON
  parsed_json = json_tokener_parse(json_str);
  if (parsed_json == NULL)
  {
    result.error = strdup("failed to parse JSON");
    return result;
  }

  // Check if the response is an error, otherwise get the data
  if (json_object_object_get_ex(parsed_json, "error", &error_json))
  {
    result.error = strdup(json_object_get_string(error_json));
    if (json_object_object_get_ex(parsed_json, "message", &message_json))
    {
      result.message = strdup(json_object_get_string(message_json));
    }
    if (!result.message)
    {
      free(result.error);
      result.error = strdup("failed to allocate memory for error message");
    }
  }
  else if (json_object_object_get_ex(parsed_json, "inputs", &inputs_array) &&
           json_object_is_type(inputs_array, json_type_array) &&
           json_object_array_length(inputs_array) > 0)
  {
    first_input_obj = json_object_array_get_idx(inputs_array, 0);
    if (json_object_object_get_ex(first_input_obj, "data", &data_json))
    {
      result.data = strdup(json_object_to_json_string(data_json));
      if (!result.data)
      {
        result.error = strdup("failed to allocate memory for data");
      }
    }
    else
    {
      result.error = strdup("data field not found in input object");
    }
  }
  else
  {
    result.error = strdup("unknown API response format");
  }

  json_object_put(parsed_json);
  return result;
}

// curl_write_func is a callback function for CURLOPT_WRITEFUNCTION.
static size_t curl_write_func(void *contents, size_t size, size_t nmemb, void *userp)
{
  // Calculate the real size of the data
  size_t real_size = size * nmemb;
  V1APIResponse *mem = (V1APIResponse *)userp;

  // Allocate memory for the response data using Postgres's memory manager
  char *ptr = (char *)palloc(mem->size + real_size + 1);
  if (ptr == NULL)
  {
    return 0; // Out of memory
  }

  // Copy the data to the allocated memory
  memcpy(ptr, mem->data, mem->size);
  memcpy(ptr + mem->size, contents, real_size);
  mem->size += real_size;
  mem->data = ptr;
  mem->data[mem->size] = 0;

  return real_size;
}

// make_v1_api_request makes a request to the v1 API.
V1APIResponse make_v1_api_request(const char *url, const char *post_data, const char *access_token)
{
  // Initialize variables
  CURL *curl;
  CURLcode res;
  struct curl_slist *headers = NULL;
  V1APIResponse response = {0, 0, NULL, 0};
  char auth_header_buffer[1024];

  // Initialize cURL
  curl_global_init(CURL_GLOBAL_ALL);
  curl = curl_easy_init();
  if (!curl)
  {
    response.error = strdup("failed to initialize cURL");
    return response;
  }

  // Set the request options
  headers = curl_slist_append(headers, "Content-Type: application/json");
  if (!embedefy_is_empty_string(access_token))
  {
    snprintf(auth_header_buffer, 1024, "Authorization: Bearer %s", access_token);
    headers = curl_slist_append(headers, auth_header_buffer);
  }
  curl_easy_setopt(curl, CURLOPT_URL, url);
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_func);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&response);

  // Perform the request
  res = curl_easy_perform(curl);
  if (res != CURLE_OK)
  {
    response.error = strdup(curl_easy_strerror(res));
  }

  // Get the HTTP response code
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response.http_code);

  // Cleanup
  curl_easy_cleanup(curl);
  curl_slist_free_all(headers);
  curl_global_cleanup();

  return response;
}
