import { readFile } from "node:fs/promises";
import { join } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

function unique(values, label) {
  const seen = new Set();
  for (const value of values) {
    if (seen.has(value)) throw new Error(`Duplicate ${label}: ${value}`);
    seen.add(value);
  }
}

function details(validate) {
  return (validate.errors ?? []).map((error) => `${error.instancePath || "/"} ${error.message}`).join("; ");
}

export function isSafeRelativePath(value) {
  if (typeof value !== "string" || !value || value.startsWith("/") || value.includes("\\") || value.includes(":") || value.includes("%")) return false;
  const segments = value.split("/");
  return segments.every((segment) => segment && segment !== "." && segment !== "..");
}

export async function createContractValidator(root) {
  const schemaDirectory = join(root, "content/schema");
  const [catalogSchema, courseSchema, integritySchema] = await Promise.all([
    readFile(join(schemaDirectory, "catalog.schema.json"), "utf8").then(JSON.parse),
    readFile(join(schemaDirectory, "course.schema.json"), "utf8").then(JSON.parse),
    readFile(join(schemaDirectory, "integrity.schema.json"), "utf8").then(JSON.parse),
  ]);
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validators = {
    catalog: ajv.compile(catalogSchema),
    course: ajv.compile(courseSchema),
    integrity: ajv.compile(integritySchema),
  };

  return {
    validateDocument(type, value) {
      const validate = validators[type];
      if (!validate) throw new Error(`Unknown contract type: ${type}`);
      if (!validate(value)) throw new Error(`Invalid ${type}: ${details(validate)}`);
    },
    validatePackage(catalog, packages) {
      this.validateDocument("catalog", catalog);
      unique(catalog.collections.map((collection) => collection.id), "collection ID");
      unique(catalog.courses.map((course) => course.id), "catalog course ID");
      const collectionIds = new Set(catalog.collections.map((collection) => collection.id));
      const descriptors = new Map(catalog.courses.map((course) => [course.id, course]));
      if (!descriptors.has(catalog.defaultCourseId)) throw new Error(`Unknown default course: ${catalog.defaultCourseId}`);
      for (const descriptor of catalog.courses) {
        if (!collectionIds.has(descriptor.collectionId)) throw new Error(`${descriptor.id} references unknown collection ${descriptor.collectionId}`);
        if (!descriptor.manifestURL.startsWith("https://") && !isSafeRelativePath(descriptor.manifestURL)) {
          throw new Error(`Unsafe manifest URL: ${descriptor.manifestURL}`);
        }
      }
      unique(packages.map((item) => item.course.id), "package course ID");
      if (packages.length !== descriptors.size) throw new Error("Catalog/package course count mismatch");
      for (const item of packages) {
        const { course, integrity } = item;
        this.validateDocument("course", course);
        this.validateDocument("integrity", integrity);
        const descriptor = descriptors.get(course.id);
        if (!descriptor) throw new Error(`Package missing from catalog: ${course.id}`);
        for (const field of ["collectionId", "title", "subtitle", "description", "kind", "practiceOrder", "contentVersion"]) {
          if (descriptor[field] !== course[field]) throw new Error(`${course.id} descriptor/course mismatch for ${field}`);
        }
        if (integrity.courseId !== course.id || integrity.contentVersion !== course.contentVersion) {
          throw new Error(`${course.id} integrity identity/version mismatch`);
        }
        unique(course.entries.map((entry) => entry.id), `${course.id} entry ID`);
        unique(integrity.files.map((file) => file.path), `${course.id} integrity path`);
        const declared = new Set(integrity.files.map((file) => file.path));
        const referenced = new Set(course.entries.map((entry) => entry.audio));
        if (!declared.has("course.json")) throw new Error(`${course.id} integrity does not declare course.json`);
        for (const path of referenced) {
          if (!isSafeRelativePath(path) || !declared.has(path)) throw new Error(`${course.id} audio is unsafe or undeclared: ${path}`);
        }
        const allowed = new Set(["course.json", ...referenced]);
        const extra = [...declared].filter((path) => !allowed.has(path));
        if (extra.length) throw new Error(`${course.id} integrity has undeclared package files: ${extra.join(", ")}`);
      }
    },
  };
}
