#include "gui.hpp"

#include <ruisapp/application.hpp>
#include <ruis/widget/button/push_button.hpp>
#include <ruis/widget/label/text.hpp>
#include <ruis/widget/container.hpp>
#include <ruis/widget/proxy/key_proxy.hpp>
#include <ruis/util/length.hpp>

using namespace std::string_literals;
using namespace std::string_view_literals;
using namespace ruis::length_literals;

namespace m {
using namespace ruis::make;
}

utki::shared_ref<ruis::widget> make_root_widget(utki::shared_ref<ruis::context> c)
{
	// clang-format off
	auto button = m::push_button(c,
		{
			.layout_params = {
				.dims = {200_pp, 60_pp}
			}
		},
		{
			m::text(c, {}, U"Exit"s)
		}
	);
	// clang-format on

	button.get().click_handler = [](ruis::push_button&) {
		ruisapp::inst().quit();
	};

	// clang-format off
	return m::pile(c,
		{
			.layout_params = {
				.align = {ruis::align::center, ruis::align::center}
			}
		},
		{
			std::move(button)
		}
	);
	// clang-format on
}
