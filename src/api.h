// pgembedefy
// For the full copyright and license information, please view the LICENSE.txt file.

#ifndef API_H
#define API_H

#include <stdbool.h>
#include <stdlib.h>
#include <curl/curl.h>
#include <postgres.h>

// V1APIResponse is a struct that holds the response from a v1 API request.
typedef struct
{
  char *data;     // Holds the response data
  size_t size;    // Holds the size of the response data
  char *error;    // Holds the error message, if any
  long http_code; // HTTP response code
} V1APIResponse;

// make_v1_api_request makes a request to the v1 API.
V1APIResponse make_v1_api_request(const char *url, const char *post_data, const char *access_token);

// V1APIResponseBody is a struct that holds the response body from a v1 API request.
typedef struct
{
  char *data;    // Holds the successful data
  char *error;   // Holds the error type/message
  char *message; // Holds additional error message if any
} V1APIResponseBody;

// parse_v1_api_response parses the response body from a v1 API request.
V1APIResponseBody parse_v1_api_response(const char *json_str);

#endif // API_H
