#include <ruisapp/application.hpp>

#include "application.hpp"

namespace hello_world {

const ruisapp::application_factory app_fac([](auto executable, auto args) {
	return make_application(executable, args);
});

} // namespace hello_world
