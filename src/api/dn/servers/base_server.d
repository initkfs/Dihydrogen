module api.dn.servers.base_server;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;

/**
 * Authors: initkfs
 */

class BaseServer : UniComposite!UniComponent
{
    bool isSystemd;
    bool isSandbox;
}
