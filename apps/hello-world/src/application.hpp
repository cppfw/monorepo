#pragma once

#include <ruisapp/application.hpp>

namespace hello_world {

class application : public ruisapp::application
{
public:
	application();

	static application& inst()
	{
		// NOLINTNEXTLINE(cppcoreguidelines-pro-type-static-cast-downcast, "here we are 100% sure the cast is safe")
		return static_cast<application&>(ruisapp::application::inst());
	}
};

} // namespace hello_world
