#pragma once

#include <ruisapp/application.hpp>

namespace hello_world {

class application : public ruisapp::application
{
public:
	application(bool windowed);

	static application& inst()
	{
		return static_cast<application&>(ruisapp::application::inst());
	}
};

std::unique_ptr<application> make_application(
	std::string_view executable, //
	utki::span<std::string_view> args
);

} // namespace hello_world
