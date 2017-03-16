// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "Kismet/BlueprintFunctionLibrary.h"
#include "NaivePhysicsLib.generated.h"

/**
 *
 */
UCLASS()
class NAIVEPHYSICS2_API UNaivePhysicsLib : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
        UFUNCTION(BlueprintCallable, Category="Utils")
        static UMaterialInterface* GetMaterialFromName(const FString& Name);

        UFUNCTION(BlueprintCallable, Category="Utils")
        static UStaticMesh* GetStaticMeshFromName(const FString& Name);
};
