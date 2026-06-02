import { Metadata } from "next";
import { HomeContent } from "./home-content";
import {
  WebApplicationSchema,
  OrganizationSchema,
} from "@/components/seo/structured-data";

export const metadata: Metadata = {
  alternates: {
    canonical: "https://agilekit.app",
  },
};

export default function HomePage() {
  return (
    <>
      <WebApplicationSchema />
      <OrganizationSchema />
      <HomeContent />
    </>
  );
}