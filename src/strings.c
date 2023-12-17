// pgembedefy
// For the full copyright and license information, please view the LICENSE.txt file.

#include <string.h>
#include <ctype.h>
#include "strings.h"

// embedefy_is_empty_string checks if a string is empty.
int embedefy_is_empty_string(const char *str)
{
  return str == NULL || strlen(str) == 0;
}
