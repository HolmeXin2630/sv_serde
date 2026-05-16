// Shared serde infrastructure — thread-local error state + string cache
#include <string>
#include <vector>
#include <cstring>

namespace serde {

thread_local std::string g_last_error;

} // namespace serde

extern "C" {

const char* dpi_serde_last_error(void) {
    return serde::g_last_error.c_str();
}

} // extern "C"
