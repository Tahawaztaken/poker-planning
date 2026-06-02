const publicSiteUrl = process.env.NEXT_PUBLIC_SITE_URL;
const publicSitePath = getPublicSitePath();

export function publicAssetPath(path: `/${string}`): string {
  return `${publicSitePath}${path}`;
}

export function buildPublicUrl(path: `/${string}`): string {
  const baseUrl = publicSiteUrl || window.location.origin;
  return `${baseUrl.replace(/\/$/, "")}${path}`;
}

export function buildPublicRoomUrl(roomId: string): string {
  return buildPublicUrl(`/room/${roomId}`);
}

function getPublicSitePath(): string {
  if (!publicSiteUrl) {
    return "";
  }

  try {
    const { pathname } = new URL(publicSiteUrl);
    return pathname === "/" ? "" : pathname.replace(/\/$/, "");
  } catch {
    return "";
  }
}
