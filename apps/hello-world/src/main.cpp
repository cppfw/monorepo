#include <ruisapp/application.hpp>

#include "application.hpp"

namespace hello_world {

const ruisapp::application_factory app_fac([](auto, auto) {
	return std::make_unique<application>();
});

} // namespace hello_world
