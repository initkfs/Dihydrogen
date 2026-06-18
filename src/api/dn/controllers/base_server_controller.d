module api.dn.controllers.base_server_controller;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;

/**
 * Authors: initkfs
 */

class BaseServerController : UniComposite!UniComponent
{
    bool isSystemd;
}
