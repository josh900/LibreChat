import React from 'react';
import { Outlet } from 'react-router-dom';
import { useAuthContext } from '~/hooks/AuthContext';
import useHealthCheck from '~/hooks/useHealthCheck';
import useAssistantsMap from '~/hooks/useAssistantsMap';
import useAgentsMap from '~/hooks/useAgentsMap';
import useFileMap from '~/hooks/useFileMap';
import useAutoModelRefresh from '~/hooks/Input/useAutoModelRefresh';

function Root() {
  const { isAuthenticated, logout } = useAuthContext();

  // Global health check - runs once per authenticated session
  useHealthCheck(isAuthenticated);

  // Auto-refresh models for user-provided endpoints
  useAutoModelRefresh();

  const assistantsMap = useAssistantsMap({ isAuthenticated });
  const agentsMap = useAgentsMap({ isAuthenticated });
  const fileMap = useFileMap({ isAuthenticated });

  return (
    <div className="flex h-screen flex-col">
      <div className="flex h-full w-full overflow-hidden">
        <Outlet />
      </div>
    </div>
  );
}

export default Root;

