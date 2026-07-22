#pragma once

#include <ruisapp/application.hpp>

namespace hello_world {

class application : public ruisapp::application
{
public:
	application();

	static application& inst()
	{
		return static_cast<application&>(ruisapp::application::inst());
	}
};

} // namespace hello_world
