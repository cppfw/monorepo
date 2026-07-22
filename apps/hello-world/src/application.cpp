#include "application.hpp"

#include <ruis/standard_widgets.hpp>
#include <ruis/widget/button/push_button.hpp>
#include <ruis/widget/label/text.hpp>
#include <ruis/widget/group/overlay.hpp>
#include <ruis/widget/proxy/key_proxy.hpp>

#include <clargs/parser.hpp>

#include "gui.hpp"

using namespace std::string_literals;
using namespace std::string_view_literals;

namespace hello_world {

application::application(bool windowed) :
	ruisapp::application({
		.name = "hello-world"s
	})
{
	auto& win = this->make_window({
		.dims = {800, 600},
		.fullscreen = !windowed
	});

	win.gui.context.get().window().close_handler = [this]() {
		this->quit();
	};

	ruis::init_standard_widgets(
		win.gui.context, //
		this->get_res_file()
	);

	auto root = make_root_widget(win.gui.context);
	win.gui.set_root(root);
}

std::unique_ptr<application> make_application(
	std::string_view executable, //
	utki::span<std::string_view> args
)
{
#if CFG_OS_NAME == CFG_OS_NAME_EMSCRIPTEN
	bool windowed = true;
#else
	bool windowed = false;

	clargs::parser p;
	p.add("window", "run in window mode", [&]() {
		windowed = true;
	});
	p.parse(args);
#endif

	return std::make_unique<application>(windowed);
}

} // namespace hello_world
