#include "application.hpp"

#include <ruis/standard_widgets.hpp>
#include <ruis/widget/button/push_button.hpp>
#include <ruis/widget/label/text.hpp>
#include <ruis/widget/container.hpp>
#include <ruis/widget/proxy/key_proxy.hpp>
#include <ruis/util/length.hpp>

using namespace std::string_literals;
using namespace std::string_view_literals;
using namespace ruis::length_literals;

namespace {

utki::shared_ref<ruis::widget> make_root_widget(utki::shared_ref<ruis::context> c)
{
	// clang-format off
	auto button = ruis::make::push_button(c,
		{
			.layout_params = {
				.dims = {200_pp, 60_pp}
			}
		},
		{
			ruis::make::text(c, {}, U"Exit"s)
		}
	);
	// clang-format on

	button.get().click_handler = [](ruis::push_button&) {
		ruisapp::inst().quit();
	};

	// clang-format off
	return ruis::make::pile(c,
		{
			.layout_params = {
				.align = {ruis::align::center, ruis::align::center}
			}
		},
		{
			ruis::make::column(c,
				{
					.layout_params = {
						.dims = {ruis::dim::min, ruis::dim::min},
						.align = {ruis::align::center, ruis::align::center}
					}
				},
				{
					ruis::make::text(c,
						{
							.layout_params = {
								.align = {ruis::align::center, ruis::align::center}
							}
						},
						U"Hello world!"s
					),
					std::move(button)
				}
			)
		}
	);
	// clang-format on
}

} // namespace

namespace hello_world {

application::application() :
	ruisapp::application({
		.name = "hello-world"s
	})
{
	auto& win = this->make_window({
		.dims = {800, 600},
		.fullscreen = false
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

} // namespace hello_world
