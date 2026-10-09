CREATE TABLE "demo" (
	"id" serial PRIMARY KEY,
	"name" text NOT NULL,
	"description" text,
	"price" numeric(10,2) DEFAULT '0' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
